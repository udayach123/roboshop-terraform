# Public IP
resource "azurerm_public_ip" "publicip" {
  name                = var.name
  location            = var.rg_location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
}

# Network Interface
resource "azurerm_network_interface" "privateip" {
  name                = var.name
  location            = var.rg_location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = var.name
    subnet_id                     = var.ip_configuration_subnet_id
    public_ip_address_id          = azurerm_public_ip.publicip.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface_security_group_association" "nsg-attach" {
  network_interface_id      = azurerm_network_interface.privateip.id
  network_security_group_id = var.network_security_group_id
}

# Virtual Machine
# variable "token" {
#   default = "hvs.vDmeXxoN570Y46tfqceaShiB"
# }

resource "azurerm_virtual_machine" "vm" {
  name                          = var.name
  location                      = var.rg_location
  resource_group_name           = var.rg_name
  network_interface_ids = [ azurerm_network_interface.privateip.id ]
  vm_size                       = "Standard_B2s"
  delete_os_disk_on_termination = true

  storage_image_reference {
    id = var.storage_image_reference_id
  }
  #source_image_id = "/subscriptions/a9bc3c93-b459-4ffb-8364-38ff9554f652/resourceGroups/golive/providers/Microsoft.Compute/images/vault-image"
  storage_os_disk {
    name              = "${var.name}-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
     computer_name  = var.name
     admin_username = data.vault_generic_secret.ssh.data[ "username" ]
     admin_password = data.vault_generic_secret.ssh.data[ "password" ]
     #admin_username = "devops18"
     #admin_password = "Passw0rd@1234"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  connection {
    type     = "ssh"
    user     = data.vault_generic_secret.ssh.data[ "username" ]
    password = data.vault_generic_secret.ssh.data[ "password" ]
    host     = azurerm_public_ip.publicip.ip_address
  }


  provisioner "remote-exec" {
    inline = [
      "export PATH=$PATH:/usr/local/bin",
      "sudo dnf install -y python3.12 python3.12-pip git",
      "python3.12 -m pip install --upgrade pip",
      "python3.12 -m pip install hvac ansible",
      "ansible-pull -i localhost, -U https://github.com/udayacharagundla/roboshop-ansible.git roboshop.yml -e app_name=${var.name} -e env=dev -e token=${var.token}"
    ]
  }
}

  # DNS A Record - Top Level Resource
resource "azurerm_dns_a_record" "dns_record" {
  name                = "${var.name}-dev"
  zone_name           = "yourtherapist.in"
  resource_group_name = var.dns_record_rg_name
  ttl                 = 3
  #records            = [azurerm_public_ip.publicip.ip_address]
  records             = [azurerm_network_interface.privateip.private_ip_address]
}
###