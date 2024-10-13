This project is run just running the pipeline in Azure DevOps. The pipeline is in the main folder in the file azure-pipelines.yml


Next steps are to run the project manually without the pipeline:
# Azure Terraform Project Setup

This project uses Terraform to manage Azure resources. It's structured with a separate backend configuration to ensure proper state management. Follow these steps to set up and run the project.

## Prerequisites

- Azure CLI installed and configured
- Terraform installed (version X.X or later)
- Azure subscription with necessary permissions

## Setup Process

### Step 1: Set up the Terraform Backend

Before applying the main Terraform configuration, we need to set up the backend to store the Terraform state.

1. Navigate to the backend configuration directory:
    
    ```bash
    cd terraform-backend
    ```
2. Initialize Terraform:

    ```bash
    terraform init
    ```   
3. Review the planned changes:

    ```bash
    terraform plan
    ```
 4. Apply the backend configuration:

    ```bash
    terraform apply
    ```
 5. Note the outputs for `storage_account_name` and `container_name`. You'll need these for the next step.

### Step 2: Configure the Main Terraform project Infrastructure
Now that the backend is set up, we can configure and apply the main Terraform project.
 
1. Return to the main project directory:

    ```bash
    cd ../azure-terraform-infra
    ```
2. Update the `backend.tf` file with the values from Step 1:
```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-backend-rg"
    storage_account_name = "<output_from_step_1>"
    container_name       = "<output_from_step_1>"
    key                  = "terraform.tfstate"
  }
}
```
3. Initialize Terraform with the new backend:

    ```bash
    terraform init
    ```
Review the planned changes:

    ```bash
    terraform plan
    ```
4. Apply the main Terraform configuration:

    ```bash



in web http://127.0,0,1:8000
In Docker http://127.0.0.1:5000 or ip:5000
 
