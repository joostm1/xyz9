# Provider aliases cannot be for_each'd. `az1` and `aw1` are the names in secret `snowflake-accounts`.
resource "terraform_data" "snowflake_account_names" {
  input = sort(keys(local.snowflake_accounts))
  lifecycle {
    precondition {
      condition = toset(keys(local.snowflake_accounts)) == toset(["az1", "aw1"]) && alltrue([
        for account in local.snowflake_accounts : contains(["azure", "aws"], account.cloud_platform)
      ])
      error_message = "Secret snowflake-accounts must contain exactly az1 and aw1, each with cloud_platform azure or aws. Add a provider alias and module call for any other name. Got: ${join(", ", sort(keys(local.snowflake_accounts)))}."
    }
  }
}
module "snowflake_account_az1" {
  source                 = "./account"
  account                = local.snowflake_accounts["az1"]
  provisioner_username   = local.config.snowflake.provisioner_username
  provisioner_public_key = tls_private_key.snowflake_provisioner["az1"].public_key_pem
  network_policies       = local.config.snowflake.platform.network_policies
  providers = {
    snowflake = snowflake.initial
  }
}
module "snowflake_account_aw1" {
  source                 = "./account"
  account                = local.snowflake_accounts["aw1"]
  provisioner_username   = local.config.snowflake.provisioner_username
  provisioner_public_key = tls_private_key.snowflake_provisioner["aw1"].public_key_pem
  network_policies       = local.config.snowflake.platform.network_policies
  providers = {
    snowflake = snowflake.aw1
  }
}
locals {
  snowflake_secret_values = merge(
    { for name, account in local.snowflake_accounts : local.account_secret_names[name].account_identifier => account.identifier },
    { for name, account in local.snowflake_accounts : local.account_secret_names[name].account_identifier_privatelink => "${lower(account.identifier)}.privatelink" },
    { for name, key in tls_private_key.snowflake_provisioner : local.account_secret_names[name].private_key => key.private_key_pem },
    { for name, key in tls_private_key.snowflake_provisioner : local.account_secret_names[name].public_key => key.public_key_pem },
    {
      (local.account_secret_names["az1"].scim_pat) = module.snowflake_account_az1.scim_token
      (local.account_secret_names["aw1"].scim_pat) = module.snowflake_account_aw1.scim_token
    }
  )
  account_bootstrap = {
    az1 = {
      provisioner_user = module.snowflake_account_az1.provisioner_user
      scim_user        = module.snowflake_account_az1.scim_user
      scim_role        = module.snowflake_account_az1.scim_role
    }
    aw1 = {
      provisioner_user = module.snowflake_account_aw1.provisioner_user
      scim_user        = module.snowflake_account_aw1.scim_user
      scim_role        = module.snowflake_account_aw1.scim_role
    }
  }
  published_accounts = {
    for name, account in local.snowflake_accounts : name => merge(account, {
      provisioner = {
        user = local.account_bootstrap[name].provisioner_user
        secret_names = {
          account_identifier             = local.account_secret_names[name].account_identifier
          account_identifier_privatelink = local.account_secret_names[name].account_identifier_privatelink
          private_key                    = local.account_secret_names[name].private_key
          public_key                     = local.account_secret_names[name].public_key
        }
        secret_resource_ids = {
          account_identifier             = azurerm_key_vault_secret.snowflake_provisioner[local.account_secret_names[name].account_identifier].resource_versionless_id
          account_identifier_privatelink = azurerm_key_vault_secret.snowflake_provisioner[local.account_secret_names[name].account_identifier_privatelink].resource_versionless_id
        }
      }
      scim = {
        service_user     = local.account_bootstrap[name].scim_user
        provisioner_role = local.account_bootstrap[name].scim_role
        pat_secret_name  = local.account_secret_names[name].scim_pat
      }
    })
  }
}
