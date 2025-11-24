# Cloud Run Environment Variables Demo

This demo illustrates the difference between setting environment variables using CLI flags (`--set-env-vars`) versus using a YAML file (`--env-vars-file`).

Using a YAML file is generally preferred for managing multiple environment variables as it keeps your deployment commands clean and allows for version controlling your configuration (excluding secrets).

## Prerequisites

- Google Cloud SDK (`gcloud`) installed and configured
- A GCP project with billing enabled

## Files

- `app/`: Contains a simple Python Flask app that returns its environment variables as JSON.
- `env-vars.yaml`: A YAML file defining a set of environment variables.
- `01-deploy-cli-flags.sh`: Deploys the app setting variables via command line flags.
- `02-deploy-yaml-file.sh`: Deploys the app setting variables via the YAML file.

## Usage

1.  **Make scripts executable:**
    ```bash
    chmod +x *.sh
    ```

2.  **Deploy using CLI flags:**
    ```bash
    ./01-deploy-cli-flags.sh
    ```
    This script runs a long `gcloud run deploy` command with many `--set-env-vars` flags.
    
    Example output:
    ```json
    {
      "deployment_method": "cli-flags",
      "environment_variables": {
        "API_KEY": "secret-key-from-cli",
        "APP_ENV": "development",
        ...
      },
      "message": "Environment Variables Demo"
    }
    ```

3.  **Deploy using YAML file:**
    ```bash
    ./02-deploy-yaml-file.sh
    ```
    This script runs a cleaner command using `--env-vars-file ../env-vars.yaml`.
    
    Example output:
    ```json
    {
      "deployment_method": "yaml-file",
      "environment_variables": {
        "API_KEY": "secret-api-key-from-yaml",
        "APP_ENV": "production",
        ...
      },
      "message": "Environment Variables Demo"
    }
    ```

4.  **Compare:**
    Notice how much cleaner the deployment command is in `02-deploy-yaml-file.sh` compared to `01-deploy-cli-flags.sh`.

## Cleanup

To remove the deployed services:

```bash
./99-cleanup.sh