# Create_TfResourceWrapper
This creates terrafrom module, core module, tfvar file and more from a tf resource name input. 

=known issues / required features

Gidi 27/9/2023 (expected)
in the following line output to "\modules\core_module\main.tf", if "NAME" not exist, we need to choose another attributes, such as ID:
for_each = { for $custom_module in try(var.region.$custom_module, []) : $custom_module.name => $custom_module } # Note if NAME not exist change it

Gidi 27/9/2023 (expected)
errors such the following seen in azuread_service_principal: "tags": conflicts with feature_tags  / "features": conflicts with feature_tags
these are different versions of the same block, note that "tags" in that context don't match the tags we use to see in azurerm objects. 

Gidi 27/9/2023 (has workaround)
Error: Invalid or unknown key........   id = var.id ........  on ..\modules\resource_modules\azuread_service_principal\main.tf
it works when changing it to "id = null" (without using the var.id which should anyway contain null), added it now in code 

Gidi 27/9/2023 (has workaround)
seems that we have a few standards to loop in dynamic blocks (lists). but some didn't seems to work.
or I was unable to access the attribute within the loop. for now changed to the last which worked for me
    for_each = var.boot_diagnostics != null ? [var.boot_diagnostics] : []
    for_each = [for del in var.delegation : {
    for_each = var.private_dns_zone_name != "" ? [1] : []
    for_each = var.feature_tags
