# Certificates

These are the steps to create a Certificate Authority (CA) and issue certificates for the AIStor/MinIO cluster.

## EasyRSA way

### Prerequisites

- RHEL-based system (tested on Rocky Linux 9)
- EasyRSA 3.1+ to create the CA and issue certificates

#### Install EasyRSA

Change to the directory where you want to install EasyRSA.
It could be any directory where you have write access.

```shell
# Get the latest release name from GitHub
export EASYRSA_RELEASE=$(curl -sL https://api.github.com/repos/OpenVPN/easy-rsa/releases/latest | grep browser_download_url | grep -o -e 'EasyRSA-[0-9.]*.tgz' | uniq)

# Download the latest release
curl -sLO https://github.com/OpenVPN/easy-rsa/releases/latest/download/${EASYRSA_RELEASE}

# Extract the release
# Don't worry about the warning
tar -xzf ${EASYRSA_RELEASE}

# Change to the release directory
cd ${EASYRSA_RELEASE%.*}

# Create a symlink to the easyrsa binary
ln -fs $PWD/easyrsa $HOME/.local/bin/
```

### Plan

- The CA will be installed on the client VM
- The CA will be used to issue certificates for the MinIO cluster
- The CA's public certificate will be installed on the MinIO client VM so that the MinIO client can verify the MinIO server certificates

### Create a Certificate Authority (CA)

#### Create a directory for the CA

```shell
# Create a directory for the CA
mkdir -p $HOME/ca

# Change to the CA directory
cd $HOME/ca
```

#### Create a vars file

Use your favorite text editor to create a file called `vars` in the CA directory.
Replace the values with your own.

```none
set_var EASYRSA_REQ_COUNTRY    "YOUR_COUNTRY"
set_var EASYRSA_REQ_PROVINCE   "YOUR_STATE"
set_var EASYRSA_REQ_CITY       "YOUR_CITY"
set_var EASYRSA_REQ_ORG        "YOUR_ORGANIZATION"
set_var EASYRSA_REQ_EMAIL      "YOUR_EMAIL"
set_var EASYRSA_REQ_OU         "YOUR_ORGANIZATIONAL_UNIT"
set_var EASYRSA_KEY_SIZE       4096
```

#### Create a new CA

```shell
easyrsa init-pki

# Build the CA
easyrsa build-ca nopass
```

### Issue Certificates

#### Get the server names and IP addresses

Each server in the lab cluster has a name in the form of `lima-LABNAME-{1..N}.internal` where `LABNAME`
is the prefix you used when creating the cluster.
E.g., if the prefix was `lab` the names will be `lima-lab1.internal`, `lima-lab2.internal`, etc.

To create certificates for the servers we need their IP addresses.
The easiest way is to use `dig` or `nslookup`.
For each server run this command (replace `lima-lab1.internal` with the actual server name)

```shell
dig lima-lab1.internal | grep -A1 'ANSWER SECTION' | sed '1d'
```

Expected output:

```none
lima-lab1.internal.     0       IN      A       192.168.104.33
```

#### Issue certificates for servers

For each server repeat these commands.
Replace `lima-lab1.internal` and `192.168.104.33` with the actual values for each server.

```shell
# Generate a certificate request
easyrsa --batch gen-req lima-lab1.internal nopass
# Sign the request
easyrsa --batch --subject-alt-name="DNS:lima-lab1.internal,DNS:localhost,IP:192.168.104.33,IP:127.0.0.1" sign-req server lima-lab1.internal
# Check the certificate
openssl x509 -in pki/issued/lima-lab1.internal.crt -text -noout
```

Or, you can use the following script.
Just change the IP address arithmetics to match your cluster.
In my case, the cluster has 4 servers and their IP addresses are `192.168.104.33`, `192.168.104.34`, `192.168.104.35`, and `192.168.104.36`.

```bash
#!/bin/bash
for i in {1..4}; do
    # Generate private key and certificate request
    easyrsa --batch gen-req lima-lab${i}.internal nopass

    # Sign the certificate
    easyrsa --batch \
            --subject-alt-name="DNS:lima-lab${i}.internal,DNS:localhost,IP:192.168.104.3$((i+2)),IP:127.0.0.1" \
            sign-req server lima-lab${i}.internal
done
```

#### Copy certificates to servers

1. **On the client VM**: Create an SSH keypair on the client VM:

   ```shell
   ssh-keygen -t ed25519
   cat ~/.ssh/id_ed25519.pub
   ```

   Expected output:

   ```none
   ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFpR0FmnEILuA2qASpsbDQuqfJC28PrWgz9M9XmBTMQa user@lima-aistor-client
   ```

   Copy the whole line above to your clipboard with **Cmd-C**.

1. **On the host (your Mac)**: Add the line above to the `authorized_keys` file on each server.
   For each server VM run the following command.
   Replace `lab1` with the actual VM names and paste the public key from the clipboard using **Cmd-V**.

   ```shell
   limactl shell lab1 bash -c 'echo "PASTE_YOUR_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys'
   ```

1. **On the client VM**: Copy the generated certificates and keys to their respective servers:
   Repeat this for each server:

   ```shell
   scp pki/issued/lima-lab1.internal.crt lima-lab1.internal:/tmp/public.crt
   scp pki/private/lima-lab1.internal.key lima-lab1.internal:/tmp/private.key
   ssh lima-lab1.internal sudo mkdir -p /etc/minio/certs
   ssh lima-lab1.internal sudo mv /tmp/public.crt /etc/minio/certs
   ssh lima-lab1.internal sudo mv /tmp/private.key /etc/minio/certs
   ssh lima-lab1.internal sudo chown -R minio-user:minio-user /etc/minio/certs
   ssh lima-lab1.internal sudo chmod 0644 /etc/minio/certs/public.crt
   ssh lima-lab1.internal sudo chmod 0600 /etc/minio/certs/private.key
   ```

### Restart MinIO servers

Add the `--certs-dir` flag to the `minio server` command in the `/etc/default/minio` file.
The edited line should look like this:

```none
MINIO_OPTS="--address :9000 --console-address :9001 --license /etc/minio/minio.license --certs-dir /etc/minio/certs"
```

Restart the MinIO `systemd` service.

```shell
sudo systemctl restart minio
```

### Install CA certificate

**On the client VM**: Install the CA certificate on the client VM.
This way all server certificates will be checked if they were signed by this CA.

The below instructions are for **RHEL-compatible** systems.

```shell
sudo cp pki/ca.crt /etc/pki/ca-trust/source/anchors/minio-ca.crt
sudo update-ca-trust
```

For Debian/Ubuntu-compatible systems copy the `ca.crt` file to the system as `/tmp/ca.crt` and then run:

```shell
sudo cp /tmp/ca.crt /usr/local/share/ca-certificates/minio-ca.crt
sudo update-ca-certificates
```

## Smallstep way

Smallstep is an alternative way to create CA and issue certificates.
One of the advantages is that with Smallstep you can create your own online certificate _service_
that will be able to issue certificates similar to Let's Encrypt.

Let's start with the offline way of generating certificates (without creating a service).

### Prerequisites

- RHEL-based system (tested on Rocky Linux 9)
- The `step` command (install it following the [instructions](https://smallstep.com/docs/step-cli/installation/))

### Create a working directory

Create a directory where you will store all PKI artifacts.

```shell
mkdir -p ~/pki-step
```

### Create a Root CA

1. Create a template file called `root.tpl`

   ```json
   {
   "subject": {
      "commonName": "MinIO Root CA",
      "country": "US",
      "province": "California",
      "locality": "Redwood City",
      "organization": "MinIO, Inc.",
      "organizationalUnit": {{ toJson .Insecure.User.organizationalUnit }},
      "email": {{ toJson .Insecure.User.email }}
   },
   "issuer": {
      "commonName": "MinIO Root CA"
   },
   "keyUsage": ["certSign", "crlSign"],
   "basicConstraints": {
      "isCA": true,
      "maxPathLen": 2
   }
   }
   ```

   As you can see, we set the permanent values for some fields (`commonName`, `organization`) and allowed
   others (`organizationalUnit`, `email`) to be configured in the command line arguments.
   You will see how to do it in the next example.

1. Create a Root CA.

   ```shell
   step certificate create --template root_ca.tpl \
   "MinIO Root CA" root_ca.crt root_ca.key \
   --set organizationalUnit="Training" \
   --set email="training@minio.io" \
   --not-after=87600h \
   --no-password \
   --insecure
   ```

   In this command:

   - "MinIO Root CA" is the **subject**.
   It could be a hostname for services or an email address for people (from the Smallstep [docs](https://smallstep.com/docs/step-cli/reference/certificate/create/#positional-arguments)).
   - `root_ca.crt` and `root_ca.key` are the files where the certificate and the key will be stored.
   - the two `--set` flags set the values for the parameters in the template above.
   - `not-after` specifies the lifetime of this Root CA certificate. Usually, it's a long period, like 10 years in this case.
   - `no-password` and `insecure` are used here for simplicity.
   In real life you should use a strong password for your Root CA and store it securely.

### Create an Intermediate CA

Usually, you don't use the Root CA to sign certificate requests. You create an Intermediate CA for that.
It is recommended that you keep your Root CA offline.

1. Create a template called `intermediate_ca.tpl`.

   ```json
   {
   "subject": {
      "commonName": "MinIO Intermediate CA",
      "country": "US",
      "province": "California",
      "locality": "Redwood City",
      "organization": "MinIO, Inc.",
      "organizationalUnit": {{ toJson .Insecure.User.organizationalUnit }},
      "email": {{ toJson .Insecure.User.email }}
   },
   "keyUsage": ["certSign", "crlSign"],
   "basicConstraints": {
      "isCA": true,
      "maxPathLen": 0
   }
   }
   ```

1. Create an Intermediate CA.

   ```shell
   step certificate create --template intermediate_ca.tpl \
   --ca root_ca.crt --ca-key root_ca.key \
   "MinIO Intermediate CA" intermediate_ca.crt intermediate_ca.key \
   --set organizationalUnit="Training" \
   --set email="training@minio.io" \
   --not-after=17520h \
   --no-password \
   --insecure
   ```

   Note that we create the Intermediate CA for only 2 years.

### Create server certificates

Now you can use the Intermediate CA to create certificates for the servers in your organization.
In our labs we use hostnames provided by Lima in te form of `lima-lab1.internal`.

1. Create a server certificate for the hostname above.

   ```shell
   step certificate create lima-lab1.internal lima-lab1.internal.crt lima-lab1.internal.key \
   --profile leaf \
   --not-after=8760h \
   --ca ./intermediate_ca.crt \
   --ca-key ./intermediate_ca.key \
   --bundle \
   --no-password \
   --insecure
   ```

   As you can see, in this case, we use `lima-lab1.internal` as a **subject** in the command.
   We use specify the certificate and key file names based on the hostname.
   We use the Intermediate CA certificate and key files that we generated above.
   We also add the flag `--bundle` to bundle this leaf certificate with the signing certificate.

1. Verify the generated certificate.

   ```shell
   step certificate inspect lima-lab1.internal.crt
   ```

   Expected output:

   ```none
   Certificate:
      Data:
         Version: 3 (0x2)
         Serial Number: 227712901324277544915640804641140940667 (0xab4fe8d781bb0be219a583ad810c9f7b)
      Signature Algorithm: ECDSA-SHA256
         Issuer: C=US,ST=California,L=Redwood City,O=MinIO, Inc.,OU=Training,CN=MinIO Intermediate CA
         Validity
               Not Before: May 25 01:59:48 2025 UTC
               Not After : May 25 01:59:48 2026 UTC
         Subject: CN=lima-lab1.internal
         Subject Public Key Info:
               Public Key Algorithm: ECDSA
                  Public-Key: (256 bit)
                  X:
                     f8:79:9a:cf:95:b1:53:ec:67:f3:d0:85:e0:b1:b4:
                     ef:81:9e:9e:79:ad:cc:79:5f:87:08:98:15:1c:12:
                     0d:6c
                  Y:
                     da:34:03:0f:fc:19:39:09:c4:d6:36:80:13:fd:06:
                     81:b9:6a:51:4e:74:53:5d:44:95:0e:eb:67:c8:86:
                     2a:1e
                  Curve: P-256
         X509v3 extensions:
               X509v3 Key Usage: critical
                  Digital Signature
               X509v3 Extended Key Usage:
                  Server Authentication, Client Authentication
               X509v3 Subject Key Identifier:
                  5C:DD:18:4A:6B:E0:7F:6E:84:1B:6A:17:CD:00:A4:88:19:E9:FB:16
               X509v3 Authority Key Identifier:
                  keyid:03:11:5D:33:E2:22:61:DB:29:38:93:C9:F2:10:FF:71:CD:A2:4A:DB
               X509v3 Subject Alternative Name:
                  DNS:lima-lab1.internal
      Signature Algorithm: ECDSA-SHA256
            30:46:02:21:00:a2:50:20:40:48:16:f3:9f:e1:b7:14:1b:85:
            a1:58:ce:93:9e:75:1d:b1:ad:54:82:4d:45:68:2a:81:f4:45:
            11:02:21:00:ba:61:54:71:6c:25:d6:c0:79:35:30:4c:88:d8:
            65:3e:45:d1:d2:e7:88:7e:c7:95:f2:69:4b:62:7e:82:b4:83
   ```

