# Rails SECRET_KEY_BASE Sync Guide

## Problem
When Rails applications use different `SECRET_KEY_BASE` values between environments, Active Storage variant URLs become inconsistent. This causes image URLs to point to non-existent files, resulting in broken images.

## Root Cause
- Rails uses `SECRET_KEY_BASE` to generate cryptographic signatures for Active Storage variant URLs
- Different `SECRET_KEY_BASE` values generate different URL paths
- In development, Rails automatically generates random secrets in `tmp/development_secret.txt`
- Production uses a fixed `SECRET_KEY_BASE` from environment variables or credentials
- When secrets don't match, local development generates URLs pointing to variants that don't exist in production storage

## Solution Overview
Sync the exact `SECRET_KEY_BASE` from production to your local development environment.

## Step-by-Step Fix

### 1. Get Production SECRET_KEY_BASE
Connect to your production environment and extract the actual secret:

```bash
# In production Rails console
rails console
puts Rails.application.secret_key_base.unpack1('H*')
```

This outputs the hexadecimal representation of the secret key.

### 2. Apply to Local Development
In your local Docker environment:

```bash
# Enter the Rails container
docker-compose exec rails bash

# Convert hex to binary and write to development secret file
ruby -e "File.write('tmp/development_secret.txt', ['YOUR_HEX_STRING_HERE'].pack('H*'))"

# Verify the file was created
cat tmp/development_secret.txt
```

### 3. Restart Development Environment
```bash
# Exit container and restart
exit
docker-compose down && docker-compose up -d
```

### 4. Verify Fix
```bash
# Test image URL generation
docker-compose exec rails rails console

# Check that SECRET_KEY_BASE matches production
puts Rails.application.secret_key_base[0..20]

# Test variant URL generation
product = Spree::Product.find(SOME_ID)
image = product.variant_images.first
puts image.url(:product)
```

The generated URL should now match the pattern used in production.

## Rails SECRET_KEY_BASE Priority Order

### Development/Test Environments
1. `Rails.application.secrets.secret_key_base` (from `config/secrets.yml`)
2. `tmp/development_secret.txt` (auto-generated file)
3. Auto-generated temporary value

### Production/Other Environments
1. `ENV["SECRET_KEY_BASE"]` (environment variable)
2. `Rails.application.credentials.secret_key_base` (from credentials file)
3. `Rails.application.secrets.secret_key_base` (from secrets.yml - deprecated)

## Alternative Solutions

### Option 1: Environment Variable
Set `SECRET_KEY_BASE` environment variable in Docker:

```yaml
# docker-compose.yml
environment:
  - SECRET_KEY_BASE=your_production_secret_here
```

### Option 2: Secrets.yml File
Create `config/secrets.yml`:

```yaml
development:
  secret_key_base: your_production_secret_here

test:
  secret_key_base: your_production_secret_here
```

### Option 3: Configuration Override
Add to `config/environments/development.rb`:

```ruby
config.secret_key_base = "your_production_secret_here"
```

## Prevention
- Document your production `SECRET_KEY_BASE` in secure team documentation
- Add this sync process to your development setup documentation
- Consider using the same master key across environments if security requirements allow
- Implement this check in your development environment setup scripts

## Security Notes
- Never commit `SECRET_KEY_BASE` values to version control
- Store production secrets securely using your team's secret management system
- The `tmp/development_secret.txt` approach is safe for local development as it's in `.gitignore`

## Troubleshooting

### Images Still Broken After Sync
1. Verify the `SECRET_KEY_BASE` matches exactly between environments
2. Check that Active Storage is configured to use the same storage service
3. Ensure variant configurations match between environments

### Rails Not Using New Secret
1. Completely restart the Rails application
2. Check that no other configuration is overriding the secret
3. Verify the temp file has the correct content and permissions

### Docker Volume Issues
If the temp file doesn't persist:
1. Check your Docker volume configuration
2. Ensure the `tmp/` directory is properly mounted
3. Consider using environment variables instead of the temp file approach