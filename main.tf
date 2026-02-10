//Netskope Resources
//
//Create Publisher in Netskope
resource "netskope_npa_publisher" "Publisher" {
  publisher_name = var.publisher_name
}


resource "netskope_npa_publisher_token" "Publisher" {
  publisher_id = netskope_npa_publisher.Publisher.publisher_id 
  lifecycle {
    replace_triggered_by = [
      null_resource.ami_change.id
    ]
  }
}

resource "null_resource" "ami_change" {
  triggers = {
    ami_id = data.aws_ami.npa-publisher.id
  }
}

//AWS Data
//
// Filter Netskope Publishers AMIs for the latests version
data "aws_ami" "npa-publisher" {
  most_recent = true
  owners      = ["679593333241"]

  filter {
    name   = "name"
    values = ["Netskope Private Access Publisher*"]
  }
}

// Create EC2 Instance for the Publisher
resource "aws_instance" "NPAPublisher" {
  ami = var.ami_id != "" ? var.ami_id : "${data.aws_ami.npa-publisher.id}"
  associate_public_ip_address = var.associate_public_ip_address
  iam_instance_profile        = var.iam_instance_profile
  instance_type               = var.aws_instance_type
  key_name                    = var.aws_key_name
  subnet_id                   = var.aws_subnet
  vpc_security_group_ids      = [var.aws_security_group]
  user_data                   = "${var.use_ssm == true ? "" : netskope_npa_publisher_token.Publisher.token}" 
  monitoring                  = var.aws_monitoring
  ebs_optimized               = var.ebs_optimized

  tags = {
    "Name" = var.publisher_name
  }
  
  metadata_options {
    http_endpoint               = var.http_endpoint
    http_tokens                 = var.http_tokens
  }


}


//Create SSM Document for Publisher with versioning
resource "aws_ssm_document" "PublisherRegistration" {
  count = var.use_ssm == true ? 1 : 0
  name          = "SSM-Register-${var.publisher_name}"
  document_type = "Command"
  
  content = jsonencode({
    schemaVersion = "1.2"
    description   = "Register a Netskope Publisher via SSM"
    parameters    = {}
    runtimeConfig = {
      "aws:runShellScript" = {
        properties = [
          {
            id         = "0.aws:runShellScript"
            runCommand = ["sudo /home/ubuntu/npa_publisher_wizard -token \"${netskope_npa_publisher_token.Publisher.token}\""]
          }
        ]
      }
    }
  })

  document_format = "JSON"
  
  # Create new version when content changes
  lifecycle {
    create_before_destroy = true
  }
}

//Associate Publisher with SSM
resource "aws_ssm_association" "register_publishers" {
  count = var.use_ssm == true ? 1 : 0
  name              = aws_ssm_document.PublisherRegistration[0].name
  association_name  = "Register-${var.publisher_name}"
  
  targets {
    key    = "InstanceIds"
    values = [aws_instance.NPAPublisher.id]
  }

  lifecycle {
    create_before_destroy = true
  }
  
  depends_on = [aws_ssm_document.PublisherRegistration]
}


