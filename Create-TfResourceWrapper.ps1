# C:\Wrapper_creator\Create-TfResourceWrapper.ps1 -terrafrom_repo_where_provider_installed "c:\TF Modules\1" -tf_exe "C:\t\1.5.4\terraform.exe" -resource_type "azurerm_mssql_managed_instance"

<#
.Synopsis
   Create Terrafrom module wrapper for a tf resource, aliging with our standard. 
.DESCRIPTION
   The script take an existing resource as an input from an initialized terraform folder.
   it takes the parameters from the json schema using the following command terrafrom.exe providers schema -json
   it then creates a folder and file structure for the module itself and it's use at the core module and tfvar.  
.EXAMPLE
    PS C:\temp> .\Create-TfResourceWrapper.ps1 -terrafrom_repo_where_provider_installed "C:\TF Modules\1"
    -tf_exe "C:\t\1.5.4\terraform.exe" -resource_type "azurerm_mssql_managed_instance"
.EXAMPLE
    PS C:\temp> .\ Create-TfResourceWrapper.ps1 -terrafrom_repo_where_provider_installed "C:\TF Modules\1"
   -tf_exe "C:\t\1.5.4\terraform.exe" -resource_type "azuread_service_principal"
   -resource_name "azuread_service_principal" -custom_module "service_principal"
   -script_output_folder "c:\TF Modules\wrapper_script_output"
.INPUTS
   these parameters are mandatory:
   -terrafrom_repo_where_provider_installed -tf_exe -resource_type
.OUTPUTS
   Files would be saved by deafult in pwd\output\resource_name, or can be set by -script_output_folder
.NOTES
    Filename: Create-TfResourceWrapper.ps1
    Author: Gidi Marcus
    Modified date: 2023-10-04
    Version 1.0 - final
.LINK
   none
#>
[cmdletbinding()]
param(
    # where is the repo with the resource type installed 
    [Parameter(Mandatory = $true)]
    [ValidateScript({test-path -path $_})]
    [string] $terrafrom_repo_where_provider_installed ,# = "C:\TF Modules\1"
    
    #where should we run the terraform.exe file
    [Parameter(Mandatory = $true)]
    [ValidateScript({test-path -path $_})]
    [string] $tf_exe ,  # "C:\t\1.5.4\terraform.exe"

    # the resource type name within the terrafrom provider
    [Parameter(Mandatory = $true)]
    [ValidateScript({
      $resource_type = $_
      $input_json = Invoke-Expression "$tf_exe -chdir=""$terrafrom_repo_where_provider_installed"" providers schema -json" | ConvertFrom-Json
      if(($input_json.provider_schemas.PSObject.Properties | Where-Object {$resource_type -in $_.value.resource_schemas.PSObject.Properties.name}).name){
        $true 
      } else {throw "Cant find resource_type in terrafrom_repo_where_provider_installed, did you run ""terrafrom,exe init"" with this provider?"}
    })]
    [string] $resource_type , # "azuread_service_principal"

    # the name of which you want to use for the resource #TODO - define this better
    [string] $resource_name = $resource_type , # "azuread_service_principal"

    # the name of which you want to use for the module #TODO - define this better
    [string] $custom_module = $(($resource_name -split "_",2) | Select-Object -Last 1) , # "service_principal" 

    # where to save ouput, default pwd\output\resource_name
    [string]$script_output_folder = "$($(get-location).path)\output\$resource_name"
)

#init vars
$input_json = Invoke-Expression "$tf_exe -chdir=""$terrafrom_repo_where_provider_installed"" providers schema -json" | ConvertFrom-Json
$provider = ($input_json.provider_schemas.PSObject.Properties | Where-Object {$resource_type -in $_.value.resource_schemas.PSObject.Properties.name}).name
$block = $input_json.provider_schemas.($provider).resource_schemas.($resource_type).block
$files_header = "# Auto-generated using Create-TfResourceWrapper.ps1 by $(([adsi]"LDAP://$(whoami /fqdn)").displayName) on $(get-date)`n`n"
$files = @{}
$files."\modules\resource_modules\$resource_name\variables.tf" = $files."\modules\core_module\outputs.tf"  = "$($files_header)"
$files."\modules\resource_modules\$resource_name\outputs.tf" = "$($files_header)#Each output in this file commented-out by deafult to reduce security risk and memory use`n`n"
$files."\modules\resource_modules\$resource_name\main.tf" = "$($files_header)resource ""$resource_type"" ""$custom_module"" {`n"
$files."\modules\core_module\locals.tf" ="$($files_header)locals {`n}"
$files."\modules\core_module\variables.tf" = "variable ""region"" {`ndefault = null`n}`n`nvariable ""tfvars"" {`ndefault = null`n}"
$files."\modules\core_module\main.tf" = "$($files_header)module ""$custom_module"" {`nsource   = ""./../resource_modules/$resource_name""
        for_each = { for $custom_module in try(var.region.$custom_module, []) : $custom_module.name => $custom_module } # Note if NAME not exist change it`n`n"
$files."\env\variables.tf" = "$($files_header)variable ""tfvars"" {`ntype = object({`ntenant_id = string`nsubscription_id = string
        tags = map(string)`n})`n}`n`nvariable ""region"" {`ntype = map(object({`nlocation = string`n`n$custom_module  = list(object({`n" 
$files."\env\tfvars.tfvars" = "$($files_header)tfvars = {`n# init`ntenant_id = ""example""`nsubscription_id = ""example""`n
        tags = {`n""example_tag1"" = ""example_value1""`n""example_tag2"" = ""example_value2""`n}`n}`n
        region = {`n""uksouth"" = {`nlocation = ""uksouth""`n$custom_module  = [`n{`n"
$files."\env\main.tf" = "/**`n* ## Description`n* `n*/`n`nterraform {`nrequired_providers {`nazurerm = {`nsource  = ""hashicorp/azurerm""
        }`n}`n}`n`nprovider ""azurerm"" {`n features {`nkey_vault {`npurge_soft_delete_on_destroy = true`nrecover_soft_deleted_key_vaults = true
        }`n}`nsubscription_id = var.tfvars.subscription_id`ntenant_id = var.tfvars.tenant_id`nskip_provider_registration = false
        }`n`nmodule ""core_module"" {`nsource = ""./../modules/core_module""`nfor_each = var.region`nregion = each.value`ntfvars = var.tfvars`n}"



#loop on attributes of main block
$attributes = $block.attributes.PSObject.Properties | Sort-Object {$_.value.optional},{$_.value.type},name
foreach ($attribute in $attributes) {
    $files."\modules\resource_modules\$resource_name\outputs.tf" += "/*`noutput ""$($attribute.name)"" {`nvalue = $($resource_name).$($custom_module).$($attribute.name)`ndescription = ""$($attribute.value.description)""`n}`n*/`n`n"
    if ($attribute.value.computed -eq $true -and $null -eq $attribute.value.optional -and $null -eq $attribute.value.required){ # checks if it only computed
      Write-Verbose "## attr is only computed ## Name: $($attribute.name), computed: $($attribute.value.computed), required: $($attribute.value.required), optional: $($attribute.value.optional)"
    } else { Write-Verbose "## attr is NOT only computed ## Name: $($attribute.name), computed: $($attribute.value.computed), required: $($attribute.value.required), optional: $($attribute.value.optional)"
      $type = if($attribute.value.type.count -lt 2){$attribute.value.type}else{"$($attribute.value.type[0])($($attribute.value.type[1]))"}
      $type_with_optional_if_applicable = if ($attribute.value.optional -eq $true){"optional($type)"}else{$type}
      $files."\modules\resource_modules\$resource_name\variables.tf" += "variable ""$($attribute.name)"" {`ntype = $type`ndescription = ""$($attribute.value.description)""`n}`n`n"
      if ($attribute.name -eq "id") {
        $files."\modules\resource_modules\$resource_name\main.tf" += "$($attribute.name) = null # there's seems to be tf bug/issue with using var.id`n"
      } else {
        $files."\modules\resource_modules\$resource_name\main.tf" += "$($attribute.name) = var.$($attribute.name)`n"
      }
      if ($attribute.name -eq "location"){
        $files."\modules\core_module\main.tf" += "location = var.region.location`n"
      } elseif ($attribute.name -eq "tags") {
        $files."\modules\core_module\main.tf" += "tags = var.tfvars.tags`n"      
      } else {
        $files."\modules\core_module\main.tf" += "$($attribute.name) = each.value.$($attribute.name)`n"
        $files."\env\tfvars.tfvars" += "$($attribute.name) = null #expecting $type_with_optional_if_applicable  ##  ""$($attribute.value.description)""`n"
        $files."\env\variables.tf" += "$($attribute.name) = $type_with_optional_if_applicable`n"
      }
  }
}
foreach ($block_name in ($block.block_types.PSObject.Properties.name)){
  #init files content in block
  $block_nesting_mode = $block.block_types.$block_name.nesting_mode
  if ($block_nesting_mode -eq "list"){
    $files."\modules\resource_modules\$resource_name\main.tf" += "`ndynamic ""$block_name"" {`nfor_each = var.$block_name `ncontent {`n"
    $files."\env\tfvars.tfvars" += "`n$block_name = [{`n"
  } else {
    $files."\modules\resource_modules\$resource_name\main.tf" += "`n$block_name {`n"
    $files."\env\tfvars.tfvars" += "`n$block_name = {`n"
  }
  if ($block_nesting_mode -eq "single"){
    $files."\env\variables.tf" += "`n$block_name = object({`n"
    $files."\modules\resource_modules\$resource_name\variables.tf" += "variable ""$block_name"" {`ntype = object({`n"
  } else {
    $files."\env\variables.tf" += "`n$block_name = $block_nesting_mode(object({`n"
    $files."\modules\resource_modules\$resource_name\variables.tf" += "variable ""$block_name"" {`ntype = $block_nesting_mode(object({`n"
  }
  #loop on attributes of block
  $attributes = $block.block_types.$block_name.block.attributes.PSObject.Properties | Sort-Object {$_.value.optional},{$_.value.type},name
  foreach ($attribute in $attributes) {
      if ($attribute.value.computed -eq $true -and $null -eq $attribute.value.optional -and $null -eq $attribute.value.required){ # checks if it only computed
        Write-Verbose "## attr is only computed ## Name: $($attribute.name), computed: $($attribute.value.computed), required: $($attribute.value.required), optional: $($attribute.value.optional)"
      } else { Write-Verbose "## attr is NOT only computed ## Name: $($attribute.name), computed: $($attribute.value.computed), required: $($attribute.value.required), optional: $($attribute.value.optional)"
        $type = if($attribute.value.type.count -lt 2){$attribute.value.type}else{"$($attribute.value.type[0])($($attribute.value.type[1]))"}
        $type_with_optional_if_applicable = if ($attribute.value.optional -eq $true){"optional($type)"}else{$type}
        $files."\env\variables.tf" += "$($attribute.name) = $type_with_optional_if_applicable`n"
        $files."\env\tfvars.tfvars" += "$($attribute.name) = null #expecting $type_with_optional_if_applicable  ##  ""$($attribute.value.description)""`n"
        $files."\modules\resource_modules\$resource_name\variables.tf" += "$($attribute.name) = $type`n"
        if ($block_nesting_mode -eq "list"){
          $files."\modules\resource_modules\$resource_name\main.tf" += "$($attribute.name) = $block_name.value.$($attribute.name)`n"
        } else {
          $files."\modules\resource_modules\$resource_name\main.tf" += "$($attribute.name) = var.$block_name.$($attribute.name)`n"
        }
    }
  }
  #close files content in block loop
  $files."\modules\core_module\main.tf" += "$block_name = each.value.$block_name`n"  
  if ($block_nesting_mode -eq "list"){
    $files."\modules\resource_modules\$resource_name\main.tf" += "}`n}`n"
    $files."\env\tfvars.tfvars" += "}]`n"
  } else {
    $files."\modules\resource_modules\$resource_name\main.tf" += "}`n"
    $files."\env\tfvars.tfvars" += "}`n"
  }
  if ($block_nesting_mode -eq "single"){
    $files."\env\variables.tf" += "})`n"
    $files."\modules\resource_modules\$resource_name\variables.tf" += "})`n}`n`n"
  } else {
    $files."\env\variables.tf" += "}))`n"
    $files."\modules\resource_modules\$resource_name\variables.tf" += "}))`n}`n`n"
  }
}
#close files content fully, out and format files
$files."\env\variables.tf" += "}))`n}))`n}"
$files."\modules\resource_modules\$resource_name\main.tf" += "}`n"
$files."\modules\core_module\main.tf" += "`ndepends_on = []`n}"
$files."\env\tfvars.tfvars" += "}`n]`n}`n}"
ForEach ($file in $files.keys){
  New-Item (split-path "$script_output_folder\$($file)" -Parent) -ItemType Directory -Force | out-null
  $files.$file | out-file "$script_output_folder\$($file)" -Encoding utf8 -force}
Invoke-Expression "$tf_exe -chdir=""$script_output_folder"" fmt -recursive" | Out-Null
Write-Host "Files saved in: $script_output_folder" -ForegroundColor "green"
