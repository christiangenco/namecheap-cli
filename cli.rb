#!/usr/bin/env ruby
# Namecheap CLI — manage domains, DNS, and registration
#
# Usage:
#   ruby cli.rb domains                          # List all domains
#   ruby cli.rb check domain1.com domain2.com    # Check availability
#   ruby cli.rb register domain.com              # Register a domain
#   ruby cli.rb dns domain.com                   # Show DNS records
#   ruby cli.rb dns:set domain.com records.json  # Set DNS records (replaces all!)
#   ruby cli.rb dns:vercel domain.com            # Point domain to Vercel
#   ruby cli.rb pricing com                      # Get pricing for a TLD
#   ruby cli.rb transfer domain.com EPP_CODE     # Submit a domain transfer
#   ruby cli.rb transfer:status TRANSFER_ID      # Check transfer status
#   ruby cli.rb transfer:list [LIST_TYPE]        # List transfers

require_relative "namecheap"
require "json"

nc = Namecheap.new

command = ARGV.shift

case command
when "domains", "list"
  domains = nc.domains
  domains.each do |d|
    status = d[:is_expired] ? " [EXPIRED]" : ""
    auto = d[:auto_renew] ? " (auto-renew)" : ""
    puts "  #{d[:name].ljust(35)}#{status}  expires: #{d[:expires]}#{auto}"
  end
  puts "\nTotal: #{domains.size} domains"

when "check"
  domains = ARGV
  abort "Usage: ruby cli.rb check domain1.com [domain2.com ...]" if domains.empty?

  results = nc.check_availability(domains)
  results.each do |r|
    status = r[:available] ? "✅ AVAILABLE" : "❌ taken"
    premium = r[:premium] ? " (premium: $#{r[:price]})" : ""
    puts "  #{r[:domain].ljust(35)} #{status}#{premium}"
  end

when "register"
  domain = ARGV.shift
  years = (ARGV.shift || "1").to_i
  abort "Usage: ruby cli.rb register domain.com [years]" unless domain

  puts "Registering #{domain} for #{years} year(s)..."
  result = nc.register(domain, years: years)
  if result[:registered]
    puts "✅ Registered #{result[:domain]}"
    puts "   Charged: $#{result[:charged]}"
    puts "   Order ID: #{result[:order_id]}"
  else
    puts "❌ Registration failed"
    puts result.inspect
  end

when "dns"
  domain = ARGV.shift
  abort "Usage: ruby cli.rb dns domain.com" unless domain

  records = nc.dns_records(domain)
  if records.empty?
    puts "  (no records for #{domain})"
  else
    puts "DNS records for #{domain}:"
    records.each do |r|
      mx = r[:type] == "MX" ? " (pref: #{r[:mx_pref]})" : ""
      puts "  #{r[:type].ljust(8)} #{r[:hostname].ljust(25)} → #{r[:address]}  TTL:#{r[:ttl]}#{mx}"
    end
  end

when "dns:set"
  domain = ARGV.shift
  file = ARGV.shift
  abort "Usage: ruby cli.rb dns:set domain.com records.json" unless domain && file

  records = JSON.parse(File.read(file), symbolize_names: true)
  puts "Setting #{records.length} DNS records for #{domain}..."
  nc.set_dns_records(domain, records)
  puts "✅ Records set"

  puts "\nVerifying..."
  nc.dns_records(domain).each do |r|
    puts "  #{r[:type].ljust(8)} #{r[:hostname].ljust(25)} → #{r[:address]}  TTL:#{r[:ttl]}"
  end

when "dns:vercel"
  domain = ARGV.shift
  abort "Usage: ruby cli.rb dns:vercel domain.com" unless domain

  puts "Pointing #{domain} to Vercel..."
  records = [
    { hostname: "@",   type: "A",     address: "216.150.1.1",          ttl: "1800" },
    { hostname: "www", type: "CNAME", address: "cname.vercel-dns.com.", ttl: "1800" },
  ]

  nc.set_dns_records(domain, records)
  puts "✅ Records set"

  puts "\nVerifying..."
  nc.dns_records(domain).each do |r|
    puts "  #{r[:type].ljust(8)} #{r[:hostname].ljust(25)} → #{r[:address]}  TTL:#{r[:ttl]}"
  end

when "transfer"
  domain = ARGV.shift
  epp_code = ARGV.shift
  abort "Usage: namecheap-cli transfer DOMAIN EPP_CODE" unless domain && epp_code

  puts "Submitting transfer for #{domain}..."
  result = nc.transfer_create(domain, epp_code)
  if result[:transfer]
    puts "✅ Transfer submitted for #{result[:domain]}"
    puts "   Transfer ID: #{result[:transfer_id]}"
    puts "   Order ID: #{result[:order_id]}"
    puts "   Charged: $#{result[:charged]}"
  else
    puts "❌ Transfer failed"
    puts result.inspect
  end

when "transfer:status"
  transfer_id = ARGV.shift
  abort "Usage: namecheap-cli transfer:status TRANSFER_ID" unless transfer_id

  result = nc.transfer_get_status(transfer_id)
  puts JSON.pretty_generate(result)

when "transfer:list"
  list_type = ARGV.shift  # optional: ALL, INPROGRESS, CANCELLED, COMPLETED
  opts = {}
  opts[:list_type] = list_type if list_type

  transfers = nc.transfer_get_list(**opts)
  puts JSON.pretty_generate(transfers)

when "pricing"
  tld = ARGV.shift || "com"
  puts "Pricing for .#{tld}:"
  prices = nc.get_pricing(tld)
  prices.each do |duration, info|
    puts "  #{duration} year(s): $#{info[:price]} (regular: $#{info[:regular_price]})"
  end

when nil, "help", "--help", "-h"
  puts <<~HELP
    Namecheap CLI

    Usage:
      namecheap-cli domains                          List all domains
      namecheap-cli check domain1.com domain2.com    Check availability
      namecheap-cli register domain.com [years]      Register a domain
      namecheap-cli dns domain.com                   Show DNS records
      namecheap-cli dns:set domain.com records.json  Set DNS records (replaces all!)
      namecheap-cli dns:vercel domain.com            Point domain to Vercel (A + CNAME)
      namecheap-cli pricing [tld]                    Get pricing for a TLD
      namecheap-cli transfer DOMAIN EPP_CODE         Submit a domain transfer
      namecheap-cli transfer:status TRANSFER_ID      Check transfer status
      namecheap-cli transfer:list [LIST_TYPE]         List transfers (ALL|INPROGRESS|CANCELLED|COMPLETED)

    Environment:
      NAMECHEAP_API_KEY       API key from namecheap.com
      NAMECHEAP_USERNAME      Namecheap username
      NAMECHEAP_CLIENT_IP     (optional) Whitelisted IP, auto-detected if not set
  HELP

else
  abort "Unknown command: #{command}. Run 'ruby cli.rb help' for usage."
end
