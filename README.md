# AWS VProfile Three-Tier Infrastructure with Terraform

![Terraform](https://img.shields.io/badge/Terraform-1.6%2B-844FBA?logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Infrastructure-232F3E?logo=amazonwebservices&logoColor=white)
![MySQL](https://img.shields.io/badge/RDS-MySQL-4479A1?logo=mysql&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg)

A complete Infrastructure as Code project that deploys a highly structured AWS environment for the VProfile Java application. The design places two Tomcat servers in private subnets behind a public Application Load Balancer and uses managed AWS services for MySQL, Memcached, and RabbitMQ.

> **Lab warning:** this project creates chargeable resources, including a NAT Gateway, an Application Load Balancer, RDS, ElastiCache, Amazon MQ, public IPv4 addresses, and EC2 instances. Destroy the environment when the lab is complete.

## Architecture

```mermaid
flowchart TB
    User((Internet User)) -->|HTTP 80| ALB[Application Load Balancer\nPublic Subnets]

    Admin((Administrator)) -->|SSH 22| Bastion[Bastion Host\nPublic Subnet]
    Bastion -->|SSH 22| T1[Tomcat EC2 1\nPrivate App Subnet AZ-1]
    Bastion -->|SSH 22| T2[Tomcat EC2 2\nPrivate App Subnet AZ-2]

    ALB -->|HTTP 8080| T1
    ALB -->|HTTP 8080| T2

    T1 -->|MySQL 3306| RDS[(Amazon RDS for MySQL)]
    T2 -->|MySQL 3306| RDS

    T1 -->|Memcached 11211| Cache[(ElastiCache Memcached)]
    T2 -->|Memcached 11211| Cache

    T1 -->|Local 5672 → TLS 5671| MQ[(Amazon MQ RabbitMQ)]
    T2 -->|Local 5672 → TLS 5671| MQ

    T1 --> NAT[NAT Gateway]
    T2 --> NAT
    NAT --> Internet((Internet))

    DNS[Route 53 Private Hosted Zone\nvprofile] -. db01.vprofile .-> RDS
    DNS -. mc01.vprofile .-> Cache
    DNS -. rmq01.vprofile .-> MQ
```

## AWS resources

| Layer | Resources |
|---|---|
| Network | VPC, Internet Gateway, one NAT Gateway, route tables, two public subnets, two private application subnets, two isolated private data subnets |
| Access | Bastion EC2 instance with an Elastic IP and restricted SSH ingress |
| Application | Two Amazon Linux 2023 EC2 instances for Apache Tomcat |
| Load balancing | Internet-facing Application Load Balancer, listener, target group, health checks, and sticky sessions |
| Database | Private Amazon RDS for MySQL instance and DB subnet group |
| Cache | Private Amazon ElastiCache for Memcached node |
| Messaging | Private Amazon MQ for RabbitMQ broker |
| DNS | Route 53 private hosted zone with `db01.vprofile`, `mc01.vprofile`, and `rmq01.vprofile` |
| Security | Dedicated security groups with service-to-service rules |
| Management | IAM instance profile with AWS Systems Manager core permissions |

## Repository structure

```text
.
├── cache.tf
├── compute.tf
├── database.tf
├── dns.tf
├── load_balancer.tf
├── locals.tf
├── mq.tf
├── networking.tf
├── outputs.tf
├── providers.tf
├── security.tf
├── variables.tf
├── versions.tf
├── terraform.tfvars.example
├── database/
│   └── db_backup.sql
├── scripts/
│   ├── init-mysql.sh
│   └── tomcat.sh
├── docs/
│   ├── GITHUB_POST.md
│   └── GITHUB_WEB_UPLOAD.md
├── LICENSE
└── README.md
```

## Design decisions

### Private application and data tiers

Only the Application Load Balancer and bastion host are reachable from the internet. Tomcat, RDS MySQL, Memcached, and RabbitMQ have no public IP addresses.

### RDS for MySQL

The Terraform configuration creates an initial database named `accounts`. The schema and sample records are stored in `database/db_backup.sql` and are imported separately from the bastion by `scripts/init-mysql.sh`.

The application uses:

```properties
jdbc.driverClassName=com.mysql.cj.jdbc.Driver
jdbc.url=jdbc:mysql://db01.vprofile:3306/accounts
```

The source application already includes MySQL Connector/J, so no MariaDB JDBC driver is required.

### Amazon MQ TLS compatibility

Amazon MQ RabbitMQ accepts secure AMQP connections on port `5671`. The legacy application expects unencrypted RabbitMQ on port `5672`, so `scripts/tomcat.sh` installs a local `stunnel` service:

```text
Java application → 127.0.0.1:5672 → stunnel → rmq01.vprofile:5671
```

The tunnel validates the AWS broker certificate and uses the real broker hostname for TLS SNI.

### ALB sticky sessions

Load balancer cookie stickiness is enabled because the legacy application stores the Spring session and CSRF token locally on each Tomcat server. This prevents the login GET and POST requests from being sent to different servers.

### Memcached compatibility

The legacy application is configured with direct Memcached endpoints and does not use ElastiCache Auto Discovery. The project therefore creates one cache node and maps `mc01.vprofile` to its node endpoint.

## Prerequisites

- An AWS account with permissions to create the resources in this project
- Terraform 1.6 or later
- AWS credentials configured locally
- An existing EC2 key pair in the selected AWS Region
- Your current public IP address in `/32` CIDR format
- OpenSSH installed on your workstation

## 1. Configure Terraform variables

Create your local variables file:

```powershell
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
notepad .\terraform.tfvars
```

Update at least:

```hcl
key_name  = "your-existing-key-pair"
admin_cidr = "YOUR.PUBLIC.IP.ADDRESS/32"

db_username = "root"
db_password = "YOUR_DATABASE_PASSWORD"

mq_username = "rabbitadmin"
mq_password = "YOUR_RABBITMQ_PASSWORD"
```

`terraform.tfvars` is ignored by Git and must not be uploaded to GitHub.

## 2. Create the AWS infrastructure

```powershell
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out vprofile.tfplan
terraform apply vprofile.tfplan
```

Amazon MQ usually takes longer than the other services to finish creating. The ALB targets remain unhealthy until Tomcat is installed.

View the important outputs:

```powershell
terraform output
terraform output -raw bastion_public_ip
terraform output -json tomcat_private_ips
terraform output -raw mysql_endpoint
terraform output -raw rabbitmq_hostname
terraform output -raw alb_url
```

## 3. Initialize the MySQL schema and sample data

The SQL file is included at:

```text
database/db_backup.sql
```

Copy the project or at least the `database` and `scripts` directories to the bastion. The following example copies both directories from PowerShell:

```powershell
$KeyPath = "C:\path\to\your-key.pem"
$Bastion = terraform output -raw bastion_public_ip

scp -i $KeyPath -r .\database "ec2-user@${Bastion}:/home/ec2-user/"
scp -i $KeyPath -r .\scripts "ec2-user@${Bastion}:/home/ec2-user/"
ssh -i $KeyPath "ec2-user@${Bastion}"
```

On the bastion, run:

```bash
chmod +x /home/ec2-user/scripts/init-mysql.sh

sudo env \
  DB_HOST='db01.vprofile' \
  DB_USER='root' \
  DB_PASSWORD='YOUR_DATABASE_PASSWORD' \
  DB_NAME='accounts' \
  /home/ec2-user/scripts/init-mysql.sh
```

The script imports the schema and validates the following tables:

```text
role
user
user_role
```

## 4. Install Tomcat on both private EC2 instances

Get the addresses from Terraform:

```powershell
$KeyPath = "C:\path\to\your-key.pem"
$Bastion = terraform output -raw bastion_public_ip
$TomcatIps = terraform output -json tomcat_private_ips | ConvertFrom-Json
```

Copy `tomcat.sh` to both private instances through the bastion:

```powershell
foreach ($PrivateIp in $TomcatIps) {
    scp -i $KeyPath `
        -o "ProxyJump=ec2-user@$Bastion" `
        .\scripts\tomcat.sh `
        "ec2-user@${PrivateIp}:/home/ec2-user/tomcat.sh"
}
```

Connect to each Tomcat instance:

```powershell
ssh -i $KeyPath `
    -J "ec2-user@$Bastion" `
    "ec2-user@TOMCAT_PRIVATE_IP"
```

Run on each Tomcat server:

```bash
chmod +x /home/ec2-user/tomcat.sh

sudo env \
  DB_PASSWORD='YOUR_DATABASE_PASSWORD' \
  MQ_PASSWORD='YOUR_RABBITMQ_PASSWORD' \
  /home/ec2-user/tomcat.sh
```

Optional overrides supported by the script include:

```bash
DB_HOST='db01.vprofile'
DB_PORT='3306'
DB_NAME='accounts'
DB_USER='root'
MEMCACHED_HOST='mc01.vprofile'
MQ_DNS_NAME='rmq01.vprofile'
MQ_USERNAME='rabbitadmin'
TOMCAT_VERSION='9.0.120'
```

The script performs the following tasks:

1. Installs Amazon Corretto 11, Git, Maven, Wget, cURL, stunnel, and supporting packages.
2. Detects and forces the Amazon Corretto 11 JDK for the build and service.
3. Downloads and verifies Apache Tomcat 9.0.120.
4. Creates the Tomcat system user and systemd unit.
5. Configures a TLS tunnel for Amazon MQ.
6. Clones the VProfile application source.
7. Updates MySQL, Memcached, and RabbitMQ settings using `sed -i`.
8. Builds the application with Maven tests skipped.
9. Deploys the WAR as `ROOT.war`.
10. Waits for the `/login` page to respond.

## 5. Validate the deployment

On each Tomcat instance:

```bash
sudo systemctl status tomcat --no-pager
sudo systemctl status vprofile-rabbitmq-tunnel --no-pager

getent hosts db01.vprofile
getent hosts mc01.vprofile
getent hosts rmq01.vprofile

sudo ss -lntp | grep -E '5672|8080'
curl -v --max-time 30 http://127.0.0.1:8080/login
```

Check the database from the bastion:

```bash
mariadb -h db01.vprofile -P 3306 -u root -p accounts
```

Then run:

```sql
SHOW TABLES;
SELECT COUNT(*) FROM role;
SELECT COUNT(*) FROM `user`;
SELECT COUNT(*) FROM user_role;
```

Open the application URL:

```powershell
terraform output -raw alb_url
```

## Troubleshooting

### `db01.vprofile: Name or service not known`

Confirm that:

- The Route 53 hosted zone is private.
- The hosted zone is associated with the same VPC as Tomcat.
- VPC DNS support and DNS hostnames are enabled.
- The `db01.vprofile` record points to the RDS hostname using a CNAME record.

Test the native endpoint returned by:

```powershell
terraform output -raw mysql_endpoint
```

### Tomcat is running but the application times out

Inspect startup logs:

```bash
sudo journalctl -u tomcat --no-pager -n 250
sudo journalctl -u vprofile-rabbitmq-tunnel --no-pager -n 100
```

Test backend ports:

```bash
timeout 5 bash -c '</dev/tcp/db01.vprofile/3306' && echo OK
timeout 5 bash -c '</dev/tcp/mc01.vprofile/11211' && echo OK
timeout 5 bash -c '</dev/tcp/rmq01.vprofile/5671' && echo OK
```

### Login loops or returns HTTP 403

Clear the browser cookies or use an InPrivate window after enabling ALB stickiness. Verify that the target group has an `AWSALB` cookie and that both targets are healthy.

### Maven, Git, or Java command not found

Run the deployment script with `sudo`. The script stops immediately if the Amazon Linux 2023 package installation fails.

## Security notes

- Never commit `terraform.tfvars`, Terraform state, PEM files, or passwords.
- Restrict `admin_cidr` to your own public IP address with `/32`.
- The lab uses HTTP on the ALB; production should use HTTPS with ACM.
- The lab uses one NAT Gateway and fixed EC2 instances; production should use one NAT Gateway per AZ and an Auto Scaling Group.
- For production, store database and broker credentials in AWS Secrets Manager.
- Enable RDS Multi-AZ, deletion protection, final snapshots, CloudWatch alarms, and centralized logs for production.

## Cost control and cleanup

Review the Terraform plan before applying. Amazon MQ, NAT Gateway, ALB, RDS, ElastiCache, EC2, public IPv4, storage, and data transfer can all generate charges.

Destroy the lab when finished:

```powershell
terraform destroy
```

## Technologies demonstrated

- Terraform and Infrastructure as Code
- AWS VPC networking and subnet design
- Application Load Balancer and sticky sessions
- Amazon EC2 and bastion access
- Amazon RDS for MySQL
- Amazon ElastiCache for Memcached
- Amazon MQ for RabbitMQ
- Route 53 private DNS
- Linux systemd services
- Apache Tomcat and Maven deployment
- Security groups and least-path network access

## License

This project is licensed under the [MIT License](LICENSE).
