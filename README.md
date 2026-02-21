# Namecheap CLI

Manage domains, DNS records, and registration via the Namecheap API.

## Setup

```bash
cd ~/tools/namecheap
bundle install
```

Create `.env` with your Namecheap API credentials:

```bash
NAMECHEAP_API_KEY=your-api-key
NAMECHEAP_USERNAME=your-username
```

Your IP must be whitelisted in Namecheap's API settings: https://ap.www.namecheap.com/settings/tools/apiaccess/whitelisted-ips

## Usage

```bash
cd ~/tools/namecheap

# List all domains on your account
ruby cli.rb domains

# Check if domains are available
ruby cli.rb check selfdrivingdfw.com commadfw.com example.io

# Register a domain
ruby cli.rb register selfdrivingdfw.com

# View DNS records
ruby cli.rb dns selfdrivingdfw.com

# Point a domain to Vercel
ruby cli.rb dns:vercel selfdrivingdfw.com

# Set DNS records from a JSON file (replaces ALL existing records)
ruby cli.rb dns:set selfdrivingdfw.com records.json

# Get pricing for a TLD
ruby cli.rb pricing com
```

## Ruby API

```ruby
require_relative 'namecheap'

nc = Namecheap.new

# List domains
nc.domains

# Check availability
nc.check_availability(["example.com", "example.io"])

# Register
nc.register("example.com", years: 1)

# DNS
nc.dns_records("example.com")
nc.set_dns_records("example.com", [
  { hostname: "@", type: "A", address: "1.2.3.4", ttl: "1800" },
])
nc.set_nameservers("example.com", ["ns1.example.com", "ns2.example.com"])
```
