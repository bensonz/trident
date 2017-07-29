############################
# K8s Master Instances
############################

resource "aws_instance" "master" {
    count = "${var.master_count}"

    ami = "${lookup(var.amis, var.region)}"
    instance_type = "${var.master_instance_type}"

    root_block_device = {
        volume_type = "gp2"
        volume_size = "${var.master_volume_size}"
    }

    vpc_security_group_ids = ["${aws_security_group.k8s-master.id}"]
    subnet_id = "${aws_subnet.kubernetes.id}"
    associate_public_ip_address = true
    iam_instance_profile = "${aws_iam_instance_profile.master_profile.name}"
    user_data = "${data.template_file.master_yaml.rendered}"
    key_name = "${var.ssh_key_name}"

    connection {
       type = "ssh",
       user = "core",
       private_key = "${file(var.ssh_private_key_path)}"
    }
    # Provision hyperkube
    provisioner "remote-exec" {
        inline = [
            "rkt fetch --insecure-options=all https://s3.cn-north-1.amazonaws.com.cn/kubernetes-bin/flannel_${var.flannel_version}.aci",
            "rkt fetch --insecure-options=all https://s3.cn-north-1.amazonaws.com.cn/kubernetes-bin/hyperkube_${var.kube_version}.aci",

            "curl https://s3.cn-north-1.amazonaws.com.cn/kubernetes-bin/hyperkube_${var.kube_version}.tar | docker load -q",

            "curl https://s3.cn-north-1.amazonaws.com.cn/kubernetes-bin/pause-amd64_${var.pause_version}.tar | docker load -q"
        ]
    }


    # Generate k8s_master server certificate
    provisioner "local-exec" {
        command = <<EOF
            ${path.module}/cfssl/generate_server.sh k8s_master "${self.public_ip},${self.private_ip},10.3.0.1,kubernetes.default,kubernetes"
EOF
    }
    # Provision k8s_etcd server certificate
    provisioner "file" {
        source = "./secrets/ca.pem"
        destination = "/home/core/ca.pem"
    }
    provisioner "file" {
        source = "./secrets/k8s_master.pem"
        destination = "/home/core/apiserver.pem"
    }
    provisioner "file" {
        source = "./secrets/k8s_master-key.pem"
        destination = "/home/core/apiserver-key.pem"
    }

    # Generate k8s_master client certificate
    provisioner "local-exec" {
        command = <<EOF
            ${path.module}/cfssl/generate_client.sh k8s_master
EOF
    }

    # Provision k8s_master client certificate
    provisioner "file" {
        source = "./secrets/client-k8s_master.pem"
        destination = "/home/core/client.pem"
    }
    provisioner "file" {
        source = "./secrets/client-k8s_master-key.pem"
        destination = "/home/core/client-key.pem"
    }

    # TODO: figure out permissions and chown, chmod key.pem files
    provisioner "remote-exec" {
        inline = [
            "sudo mkdir -p /etc/kubernetes/ssl",
            "sudo cp /home/core/{ca,apiserver,apiserver-key,client,client-key}.pem /etc/kubernetes/ssl/.",
            "rm /home/core/{apiserver,apiserver-key}.pem",
            "sudo mkdir -p /etc/ssl/etcd",
            "sudo mv /home/core/{ca,client,client-key}.pem /etc/ssl/etcd/.",
        ]
    }

    # Start kubelet and create kube-system namespace
    provisioner "remote-exec" {
        inline = [
            "sudo systemctl daemon-reload",
            "curl --cacert /etc/kubernetes/ssl/ca.pem --cert /etc/kubernetes/ssl/client.pem --key /etc/kubernetes/ssl/client-key.pem -X PUT -d 'value={\"Network\":\"10.2.0.0/16\",\"Backend\":{\"Type\":\"vxlan\"}}' https://${aws_instance.etcd.private_ip}:2379/v2/keys/coreos.com/network/config",
            "sudo systemctl start flanneld",
            "sudo systemctl enable flanneld",
            "sudo systemctl start kubelet",
            "sudo systemctl enable kubelet"
        ]
    }
    tags {
      Name = "k8s-master-${count.index}"
    }
}

output "kubernetes_master_public_ip" {
    value = "${join(",", aws_instance.master.*.public_ip)}"
}

data "template_file" "master_yaml" {
    template = "${file("${path.module}/k8s/master.yaml")}"
    vars {
        DNS_SERVICE_IP = "10.3.0.10"
        ETCD_IP = "${aws_instance.etcd.private_ip}"
        POD_NETWORK = "10.2.0.0/16"
        SERVICE_IP_RANGE = "10.3.0.0/24"
        HYPERKUBE_IMAGE = "${var.kube_image}"
        HYPERKUBE_VERSION = "${var.kube_version}"
    }
}