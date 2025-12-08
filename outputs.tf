output "lb_public_ip" {
  value = aws_instance.lb.public_ip
}

output "front_private_ips" {
  value = [aws_instance.front1.private_ip, aws_instance.front2.private_ip]
}

output "back_private_ips" {
  value = [aws_instance.back1.private_ip, aws_instance.back2.private_ip]
}

output "db_private_ip" {
  value = aws_instance.db.private_ip
}

output "ssh_key_instructions" {
  value = "To SSH to instances: 1) Download ssh-pet.pem from AWS EC2 Key Pairs console, 2) Place in ~/.ssh/, 3) chmod 600 ~/.ssh/ssh-pet.pem"
}
