# Create Security Group for ALB
resource "aws_security_group" "alb_sg_3" {
  name        = "alb-sg-3"
  description = "Security group for ALB"
  
  vpc_id = "vpc-0efc01cc9b85be06b"  

  # Allow all incoming traffic
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  # Allow all outgoing traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}