# namecheap-cli

Domain management via Namecheap API. Check availability, register, manage DNS.

## Commands

```bash
namecheap-cli domains                          # List all domains
namecheap-cli check domain1.com [domain2.com]  # Check availability
namecheap-cli register domain.com [years]      # Register a domain
namecheap-cli dns domain.com                   # Show DNS records
namecheap-cli dns:set domain.com records.json  # Set DNS records (replaces all!)
namecheap-cli dns:vercel domain.com            # Point domain to Vercel (A + CNAME)
namecheap-cli pricing [tld]                    # Get pricing for a TLD
namecheap-cli transfer DOMAIN EPP_CODE         # Submit a domain transfer
namecheap-cli transfer:status TRANSFER_ID      # Check transfer status
namecheap-cli transfer:list [LIST_TYPE]        # List transfers (ALL|INPROGRESS|CANCELLED|COMPLETED)
```

## Examples

```bash
namecheap-cli check selfdrivingdfw.com commadfw.com
namecheap-cli register selfdrivingdfw.com
namecheap-cli register selfdrivingdfw.com 2     # Register for 2 years
namecheap-cli dns selfdrivingdfw.com
namecheap-cli dns:vercel selfdrivingdfw.com
namecheap-cli pricing com
namecheap-cli transfer example.com AUTH_CODE_HERE
namecheap-cli transfer:status 12345
namecheap-cli transfer:list
namecheap-cli transfer:list INPROGRESS
```

Requires `.env` with `NAMECHEAP_API_KEY`, `NAMECHEAP_USERNAME`. See `.env.example`.
Your IP must be whitelisted at https://ap.www.namecheap.com/settings/tools/apiaccess/whitelisted-ips
Add funds: https://ap.www.namecheap.com/profile/billing/Topup
