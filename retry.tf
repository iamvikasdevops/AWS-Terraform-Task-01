provider "aws" {
  region                  = "ap-south-1"
  profile                 = "hybrid"
}

// create key file 
resource "tls_private_key" "tls_key" {
  algorithm   = "RSA"
}
//generating key_value_pair
resource "aws_key_pair" "key_value" {
key_name ="webec2-key"
public_key ="${tls_private_key.tls_key.public_key_openssh}"
depends_on =[tls_private_key.tls_key]
}

//saving key file

resource "local_file" "key-file" {
content ="${tls_private_key.tls_key.private_key_pem}"
filename ="webec2-key.pem"
depends_on =[tls_private_key.tls_key]
}

// creating Security_group

resource "aws_security_group" "Sec_G" {
  name        = "web-sg"
  description = "Allow https"
  

  ingress {
    description = "SSH Rule"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description="HTTP Rule"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  }

//created ec2-instance

resource "aws_instance" "web-ec2" {
  ami           = "ami-0447a12f28fddb066" 
  instance_type = "t2.micro"
  key_name      = "${aws_key_pair.key_value.key_name}"
  security_groups=["${aws_security_group.Sec_G.name}","default"]

tags = {

  name="vikas-web"

       }

depends_on=[aws_security_group.Sec_G,                        aws_key_pair.key_value]
          





//resource "null_resource" "remote1" {
  
//depends_on = [ aws_instance.web-ec2, ]

 provisioner "remote-exec"{

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.tls_key.private_key_pem}"
    host     = "${aws_instance.web-ec2.public_ip}"
          }

inline=["sudo yum install httpd -y",
        "sudo yum install git -y",
        "sudo systemctl start httpd"
       ]
        
}
 }





 




// creating volume
resource "aws_ebs_volume" "ec2-vol" {
  availability_zone = "${aws_instance.web-ec2.availability_zone}"
  size              = 1

  tags = {
    Name = "web-vol"
  }
}
//attaching volume
resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = "${aws_ebs_volume.ec2-vol.id}"
  instance_id = "${aws_instance.web-ec2.id}"
  force_detach=true

provisioner "remote-exec" {
    connection {
      agent       = "false"
      type        = "ssh"
      user        = "ec2-user"
      private_key = "${tls_private_key.tls_key.private_key_pem}"
      host        = "${aws_instance.web-ec2.public_ip}"
    }

inline= [ 
      "sudo mkfs.ext4 /dev/sdh",
      "sudo mount /dev/sdh /var/www/html/",
      "sudo rm -rvf /var/www/html/*",
      "sudo git clone https://github.com/iamvikasdevops/AWS-Terraform-Task-01.git /var/www/html/"
         ]

}
depends_on= [aws_instance.web-ec2,
             aws_ebs_volume.ec2-vol]





}
// creating s3 bucket
resource "aws_s3_bucket" "bucket" {
  bucket = "vikas123-bucket"
  acl    = "public-read"

  tags = {
    Name        = "vikas123-bucket"
  }
}
//creating s3 bucket-object
resource "aws_s3_bucket_object" "bucket-object" {
  key        = "task01.png"
  bucket     = "${aws_s3_bucket.bucket.id}"
  source     = "C:/Users/vikas/Desktop/task01.png"
  acl        = "public-read"
}


// creating cloudfront distribution for web-server
resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.bucket.bucket_regional_domain_name}"
    origin_id   = "${aws_s3_bucket.bucket.id}"
}

  enabled             = true
  is_ipv6_enabled     = false
  comment             = "CDN"
  default_root_object = "aws_s3_bucket_object.bucket-object"

 default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${aws_s3_bucket.bucket.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["IN"]
    }
  }

  viewer_certificate {
cloudfront_default_certificate = true
}
depends_on =[aws_s3_bucket.bucket]
}

output "instance_ip" {
  value = ["${aws_instance.web-ec2.public_ip}"]
}


  
