############################
# Amazon EIP association
############################
# This module simply relates an eip to an instance
resource "aws_eip_association" "eip_assoc" {
  instance_id   = "${var.instance_id}"
  allocation_id = "${var.allocation_id}"
}
