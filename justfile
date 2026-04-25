set dotenv-load := true

# Alias

alias t := mise-tools

# Terraform aliases

alias i := init
alias p := plan
alias a := apply
alias d := destroy

# Utilities

# List available solutions (directories with main.tf)
@solutions:
    echo "Available solutions:"
    ls -d */ | grep -v '^\.' | sed 's|/$||' | sed 's|^|  |'

# Check current AWS identity
@aws-check:
    aws sts get-caller-identity

# List mise tools installed in current directory
@mise-tools:
    mise ls --json | jq -r --arg pwd "$(pwd)" 'to_entries[] | select(.value[].source.path != null and (.value[].source.path | contains($pwd))) | .key'

# Terraform commands - all run in solution directories using -chdir

# Initialize terraform in a solution directory
# Usage: just init SOLUTION
@init SOLUTION:
    terraform -chdir={{ SOLUTION }} init

# Create a plan in a solution directory
# Usage: just plan SOLUTION
@plan SOLUTION *arg:
    terraform -chdir={{ SOLUTION }} plan {{ arg }} -out plan

# Apply a plan in a solution directory
# Usage: just apply SOLUTION
@apply SOLUTION *arg:
    terraform -chdir={{ SOLUTION }} apply {{ arg }} plan

# Create and apply a destroy plan
# Usage: just destroy SOLUTION
@destroy SOLUTION *arg:
    terraform -chdir={{ SOLUTION }} plan {{ arg }} -destroy -out destroy
    just _confirm-destroy {{ SOLUTION }}

[confirm("Are you sure you want to destroy all Terraform resources? This action cannot be undone.")]
@_confirm-destroy SOLUTION:
    terraform -chdir={{ SOLUTION }} apply destroy

# Validate terraform configuration
# Usage: just validate SOLUTION
@validate SOLUTION:
    terraform -chdir={{ SOLUTION }} validate

# Format terraform files
# Usage: just fmt SOLUTION
@fmt SOLUTION:
    terraform -chdir={{ SOLUTION }} fmt -write=true -recursive

# Generate terraform documentation
# Usage: just docs SOLUTION
@docs SOLUTION:
    terraform-docs markdown table --output-file={{ SOLUTION }}/README.md --output-mode=replace {{ SOLUTION }}

# Show terraform state
# Usage: just show SOLUTION
@show SOLUTION:
    terraform -chdir={{ SOLUTION }} show

# List terraform state resources
# Usage: just state SOLUTION
@state SOLUTION:
    terraform -chdir={{ SOLUTION }} state list

# Refresh terraform state
# Usage: just refresh SOLUTION
@refresh SOLUTION:
    terraform -chdir={{ SOLUTION }} refresh

# Toggle deprecated arguments in S3 migration config
# Usage: just deprecate
[working-directory: 's3-deprecation-migration']
@deprecate:
    # Check if deprecated args are currently commented (lines 39-70 start with '#')
    if grep -q '^  # acl' main.tf; then \
        sed -i '39,70s/^  # /  /' main.tf; \
        echo "Deprecated arguments ENABLED"; \
    else \
        sed -i '39,70s/^  /  # /' main.tf; \
        echo "Deprecated arguments DISABLED"; \
    fi
