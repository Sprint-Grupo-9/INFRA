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
