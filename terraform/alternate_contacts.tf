resource "aws_account_alternate_contact" "billing" {
  for_each = local.alternate_contacts.enabled ? local.member_account_ids : toset([])

  alternate_contact_type = "BILLING"
  account_id             = each.key

  name          = try(local.alternate_contacts[each.key].billing.name, local.alternate_contacts.default.billing.name)
  title         = try(local.alternate_contacts[each.key].billing.title, local.alternate_contacts.default.billing.title)
  email_address = try(local.alternate_contacts[each.key].billing.email, local.alternate_contacts.default.billing.email)
  phone_number  = try(local.alternate_contacts[each.key].billing.phone, local.alternate_contacts.default.billing.phone)
}

resource "aws_account_alternate_contact" "operations" {
  for_each = local.alternate_contacts.enabled ? local.member_account_ids : toset([])

  alternate_contact_type = "OPERATIONS"
  account_id             = each.key

  name          = try(local.alternate_contacts[each.key].operations.name, local.alternate_contacts.default.operations.name)
  title         = try(local.alternate_contacts[each.key].operations.title, local.alternate_contacts.default.operations.title)
  email_address = try(local.alternate_contacts[each.key].operations.email, local.alternate_contacts.default.operations.email)
  phone_number  = try(local.alternate_contacts[each.key].operations.phone, local.alternate_contacts.default.operations.phone)
}

resource "aws_account_alternate_contact" "security" {
  for_each = local.alternate_contacts.enabled ? local.member_account_ids : toset([])

  alternate_contact_type = "SECURITY"
  account_id             = each.key

  name          = try(local.alternate_contacts[each.key].security.name, local.alternate_contacts.default.security.name)
  title         = try(local.alternate_contacts[each.key].security.title, local.alternate_contacts.default.security.title)
  email_address = try(local.alternate_contacts[each.key].security.email, local.alternate_contacts.default.security.email)
  phone_number  = try(local.alternate_contacts[each.key].security.phone, local.alternate_contacts.default.security.phone)
}
