# Moveo Assignment

This Terraform configuration deploys an infrastructure on AWS to host an NGINX server in a private EC2 instance.  
The instance is accessible via an Application Load Balancer (ALB) in public subnets.

## Prerequisites

- AWS account with necessary permissions
- [Terraform installed](https://www.terraform.io/downloads)
- Access to an AWS key pair for SSH access (optional)
- Your `aws_access_key`, `aws_secret_key`, and `key_name` set up as environment variables or in a `.tfvars` file

## Project Structure

- **VPC and Subnets**: Sets up a VPC with public and private subnets.
- **Internet Gateway and NAT Gateway**: Provides Internet access for public and private resources.
- **Security Groups**: Manages access to the load balancer and EC2 instance.
- **Application Load Balancer**: Provides an entry point to access the NGINX instance in the private subnet.
- **EC2 Instance**: Hosts NGINX, located in the private subnet and registered with the load balancer.

## Variables

| Variable         | Description                          |
| ---------------- | ------------------------------------ |
| `aws_access_key` | Your AWS access key ID               |
| `aws_secret_key` | Your AWS secret access key           |
| `key_name`       | Key pair name for EC2 access         |
| `region`         | AWS region (default: `eu-central-1`) |

## Steps to Deploy

1. **Configure Variables**: Define your AWS credentials and key pair. You can:

   - Use `.tfvars` file:
     ```hcl
     aws_access_key = "YOUR_ACCESS_KEY"
     aws_secret_key = "YOUR_SECRET_KEY"
     key_name       = "YOUR_KEY_PAIR"
     ```

2. **Run Terraform Commands**:

   - **Initialize Terraform**: This installs the necessary provider plugins for Terraform.

     ```bash
     terraform init
     ```

   - **Preview the Plan**: This shows you what changes Terraform will make to your infrastructure.

     ```bash
     terraform plan
     ```

   - **Deploy the Infrastructure**: This will create the resources defined in your Terraform configuration.
     ```bash
     terraform apply
     ```

3. **Access the NGINX Server**:

   After deployment, find the output `load_balancer_dns` in the terminal. Access the NGINX instance by navigating to: [Link](http://app-lb-1682889749.eu-central-1.elb.amazonaws.com/)  
   **Note**: Currently all the machines are turned off, as soon as you check the assignment I will be happy to restart them and send an updated link that will 100% work.

## Resources Created

1. **Provider**: AWS provider configured with the specified region and credentials.

2. **AMI Data Source**: Retrieves the latest Ubuntu AMI from Canonical's AWS account for use in launching the EC2 instance.

3. **VPC**: Creates a custom VPC with a CIDR block of `10.0.0.0/16`.

4. **Subnets**:

- **Public Subnet**: `10.0.1.0/24` in `eu-central-1a` for hosting the public resources.
- **Public Subnet 2**: `10.0.3.0/24` in `eu-central-1b` for high availability with another public subnet.
- **Private Subnet**: `10.0.2.0/24` in `eu-central-1a` for hosting the private EC2 instance.

5. **Internet Gateway**: Allows Internet access to the public subnets.

6. **Route Tables**:

- **Public Route Table**: Routes Internet traffic from the public subnets through the Internet Gateway.
- **Private Route Table**: Routes outbound traffic from the private subnet through the NAT Gateway for Internet access.

7. **Elastic IP and NAT Gateway**: The Elastic IP is associated with the NAT Gateway to allow private subnet instances to access the Internet.

8. **Security Groups**:

- **Load Balancer Security Group**: Allows incoming HTTP and HTTPS traffic (ports `80` and `443`).
- **Private Instance Security Group**: Restricts inbound traffic to HTTP traffic from the load balancer's security group.

9. **Load Balancer**:

- Application Load Balancer configured with listeners on port `80` to handle incoming HTTP traffic.
- The ALB is configured to forward traffic to the private EC2 instance via the target group.

10. **EC2 Instance**: Ubuntu instance running NGINX, hosted in the private subnet, and registered with the load balancer target group. The instance does not have a public IP.

11. **Output**:

- **Load Balancer DNS Name**: Outputs the DNS name of the load balancer, which can be used to access the NGINX server.  
  When we search on the internet we get:  
  ![alt text](<final solution-1.jpeg>)

## Cleanup

To remove all resources created by this Terraform configuration, run:

```bash
terraform destroy

```
