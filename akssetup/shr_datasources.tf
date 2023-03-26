# declare all necessary data sources here
#
# ---------------------------------------------------------------------------------------------------------------------------------

# this universal datasource reads details about the subscription being deployed to

data "azurerm_subscription" "activesubscription" {
}

data "azurerm_resource_group" "aksrg"{
  name = var.attendee
}
