# Image Issues Troubleshooting Guide

## Common Image Problems in Development

### 🚨 Images Work in Production but Broken in Development

**Symptoms:**
- Images display correctly on production website
- Same images show as broken/404 in local development
- URLs look similar but have different hash segments

**Root Cause:** 
Local development is using a different `SECRET_KEY_BASE` than production, causing Active Storage to generate different variant URL signatures.

**Quick Fix:**
```bash
# 1. Get production secret (run in production Rails console)
puts Rails.application.secret_key_base.unpack1('H*')

# 2. Apply to local development (run in local Docker container)
docker-compose exec rails bash
ruby -e "File.write('tmp/development_secret.txt', ['PASTE_HEX_HERE'].pack('H*'))"
exit

# 3. Restart development environment
docker-compose down && docker-compose up -d
```

**Verification:**
```bash
docker-compose exec rails rails console
# Should match production secret
puts Rails.application.secret_key_base[0..20]
```

### 🔍 How to Identify SECRET_KEY_BASE Mismatch

**Production URL Pattern:**
```
https://your-bucket.com/as/variants/xyz/fb/f34704efc7/a4554a7956/...
```

**Local Development URL Pattern (when broken):**
```
https://your-bucket.com/as/variants/xyz/95/ee822d56c2/ddeb01e03f/...
```

Notice the different hash segments after `/variants/xyz/` - this indicates different `SECRET_KEY_BASE` values.

### 📁 File Locations

- **Production secret source:** Environment variables or Rails credentials
- **Local development secret:** `tmp/development_secret.txt` (highest priority)
- **Fallback secrets:** `config/secrets.yml` or Rails auto-generation

### ⚡ Quick Commands

**Check current local secret:**
```bash
docker-compose exec rails rails console -e "puts Rails.application.secret_key_base[0..20]"
```

**Check if images work:**
```bash
docker-compose exec rails rails console
p = Spree::Product.find(29184)  # Replace with actual product ID
puts p.variant_images.first.url(:product)
```

**Reset to auto-generated secret (if needed):**
```bash
docker-compose exec rails bash
rm tmp/development_secret.txt
exit
docker-compose restart rails
```

### 🛠 Alternative Solutions

If the temp file approach doesn't work:

**Option 1: Environment Variable**
```yaml
# docker-compose.yml
services:
  rails:
    environment:
      - SECRET_KEY_BASE=production_secret_here
```

**Option 2: Secrets File**
```yaml
# config/secrets.yml
development:
  secret_key_base: production_secret_here
```

**Option 3: Development Configuration**
```ruby
# config/environments/development.rb
config.secret_key_base = "production_secret_here"
```

### 🔒 Security Notes

- ✅ Safe to use production `SECRET_KEY_BASE` in local development
- ❌ Never commit secrets to version control
- ✅ `tmp/development_secret.txt` is in `.gitignore` by default
- ✅ Document the production secret in your team's secure documentation

### 🚨 Emergency Reset

If you've made changes and need to start fresh:

```bash
# Remove all local secret overrides
docker-compose exec rails bash
rm -f tmp/development_secret.txt
rm -f config/secrets.yml
exit

# Restart and Rails will auto-generate new secrets
docker-compose down && docker-compose up -d
```

**Note:** This will break image URLs again, requiring re-sync with production.

### 📋 Setup Checklist for New Developers

- [ ] Clone repository
- [ ] Run `docker-compose up -d`
- [ ] Test image display in development
- [ ] If images broken, follow "Quick Fix" steps above
- [ ] Verify images work after secret sync
- [ ] Document any issues in team knowledge base

### 🔄 Regular Maintenance

**When to Re-sync Secrets:**
- Production `SECRET_KEY_BASE` changes
- Setting up new development environment
- After major Rails upgrades
- When images suddenly stop working

**Automation Opportunity:**
Consider adding secret sync to your development setup scripts:

```bash
#!/bin/bash
# dev-setup.sh
echo "Setting up development environment..."
docker-compose up -d

echo "Syncing image secrets with production..."
# Add your secret sync commands here

echo "Development environment ready!"
```