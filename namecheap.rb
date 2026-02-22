require "net/http"
require "uri"
require "nokogiri"
require "dotenv"

Dotenv.load(File.expand_path(".env", __dir__))

class Namecheap
  API_URL = "https://api.namecheap.com/xml.response"

  def initialize(
    api_key: ENV.fetch("NAMECHEAP_API_KEY"),
    username: ENV.fetch("NAMECHEAP_USERNAME"),
    client_ip: ENV.fetch("NAMECHEAP_CLIENT_IP", nil)
  )
    @api_key = api_key
    @username = username
    @client_ip = client_ip || detect_ip
  end

  # Returns an array of hashes with domain info:
  #   { name:, expires:, is_expired:, auto_renew: }
  def domains
    results = []
    page = 1

    loop do
      doc = api_call("namecheap.domains.getList", {
        "Page" => page.to_s,
        "PageSize" => "100"
      })

      doc.css("DomainGetListResult Domain").each do |node|
        results << {
          name: node["Name"],
          expires: node["Expires"],
          is_expired: node["IsExpired"] == "true",
          auto_renew: node["AutoRenew"] == "true"
        }
      end

      paging = doc.at_css("Paging")
      total = paging.at_css("TotalItems").text.to_i
      page_size = paging.at_css("PageSize").text.to_i
      break if page * page_size >= total

      page += 1
    end

    results
  end

  # Check availability of one or more domains.
  # Pass a single domain string or an array of domain strings.
  # Returns an array of hashes: { domain:, available:, premium:, price: }
  def check_availability(domains)
    domains = Array(domains)
    doc = api_call("namecheap.domains.check", {
      "DomainList" => domains.join(",")
    })

    doc.css("DomainCheckResult").map do |node|
      {
        domain: node["Domain"],
        available: node["Available"] == "true",
        premium: node["IsPremiumName"] == "true",
        price: node["PremiumRegistrationPrice"]
      }
    end
  end

  # Get pricing for a TLD (e.g., "com", "io", "dev")
  def get_pricing(tld = "com")
    doc = api_call("namecheap.users.getPricing", {
      "ProductType" => "DOMAIN",
      "ProductCategory" => "REGISTER",
      "ActionName" => "REGISTER",
      "ProductName" => tld
    })

    prices = {}
    doc.css("ProductType ProductCategory Product Price").each do |node|
      duration = node["Duration"]
      prices[duration] = {
        duration: duration,
        currency: node["Currency"],
        price: node["Price"],
        regular_price: node["RegularPrice"]
      }
    end
    prices
  end

  # Register a new domain.
  # Requires registrant contact info — uses defaults from Namecheap account profile.
  def register(domain, years: 1)
    parts = domain.split(".")
    sld = parts[0..-2].join(".")
    tld = parts[-1]

    # Use WhoIsGuard and account defaults
    params = {
      "DomainName" => domain,
      "Years" => years.to_s,
      "AddFreeWhoisguard" => "yes",
      "WGEnabled" => "yes",
      # Registrant info — uses account defaults via Namecheap API
      # These are required fields; Namecheap fills from your profile
      "RegistrantFirstName" => ENV.fetch("NAMECHEAP_FIRST_NAME", "Christian"),
      "RegistrantLastName" => ENV.fetch("NAMECHEAP_LAST_NAME", "Genco"),
      "RegistrantAddress1" => ENV.fetch("NAMECHEAP_ADDRESS", "2028 E Ben White Blvd #240-8529"),
      "RegistrantCity" => ENV.fetch("NAMECHEAP_CITY", "Austin"),
      "RegistrantStateProvince" => ENV.fetch("NAMECHEAP_STATE", "TX"),
      "RegistrantPostalCode" => ENV.fetch("NAMECHEAP_ZIP", "78741"),
      "RegistrantCountry" => ENV.fetch("NAMECHEAP_COUNTRY", "US"),
      "RegistrantPhone" => ENV.fetch("NAMECHEAP_PHONE", "+1.5555555555"),
      "RegistrantEmailAddress" => ENV.fetch("NAMECHEAP_EMAIL", "christian@gen.co"),
      # Tech contact (same as registrant)
      "TechFirstName" => ENV.fetch("NAMECHEAP_FIRST_NAME", "Christian"),
      "TechLastName" => ENV.fetch("NAMECHEAP_LAST_NAME", "Genco"),
      "TechAddress1" => ENV.fetch("NAMECHEAP_ADDRESS", "2028 E Ben White Blvd #240-8529"),
      "TechCity" => ENV.fetch("NAMECHEAP_CITY", "Austin"),
      "TechStateProvince" => ENV.fetch("NAMECHEAP_STATE", "TX"),
      "TechPostalCode" => ENV.fetch("NAMECHEAP_ZIP", "78741"),
      "TechCountry" => ENV.fetch("NAMECHEAP_COUNTRY", "US"),
      "TechPhone" => ENV.fetch("NAMECHEAP_PHONE", "+1.5555555555"),
      "TechEmailAddress" => ENV.fetch("NAMECHEAP_EMAIL", "christian@gen.co"),
      # Admin contact (same as registrant)
      "AdminFirstName" => ENV.fetch("NAMECHEAP_FIRST_NAME", "Christian"),
      "AdminLastName" => ENV.fetch("NAMECHEAP_LAST_NAME", "Genco"),
      "AdminAddress1" => ENV.fetch("NAMECHEAP_ADDRESS", "2028 E Ben White Blvd #240-8529"),
      "AdminCity" => ENV.fetch("NAMECHEAP_CITY", "Austin"),
      "AdminStateProvince" => ENV.fetch("NAMECHEAP_STATE", "TX"),
      "AdminPostalCode" => ENV.fetch("NAMECHEAP_ZIP", "78741"),
      "AdminCountry" => ENV.fetch("NAMECHEAP_COUNTRY", "US"),
      "AdminPhone" => ENV.fetch("NAMECHEAP_PHONE", "+1.5555555555"),
      "AdminEmailAddress" => ENV.fetch("NAMECHEAP_EMAIL", "christian@gen.co"),
      # Aux billing contact (same as registrant)
      "AuxBillingFirstName" => ENV.fetch("NAMECHEAP_FIRST_NAME", "Christian"),
      "AuxBillingLastName" => ENV.fetch("NAMECHEAP_LAST_NAME", "Genco"),
      "AuxBillingAddress1" => ENV.fetch("NAMECHEAP_ADDRESS", "2028 E Ben White Blvd #240-8529"),
      "AuxBillingCity" => ENV.fetch("NAMECHEAP_CITY", "Austin"),
      "AuxBillingStateProvince" => ENV.fetch("NAMECHEAP_STATE", "TX"),
      "AuxBillingPostalCode" => ENV.fetch("NAMECHEAP_ZIP", "78741"),
      "AuxBillingCountry" => ENV.fetch("NAMECHEAP_COUNTRY", "US"),
      "AuxBillingPhone" => ENV.fetch("NAMECHEAP_PHONE", "+1.5555555555"),
      "AuxBillingEmailAddress" => ENV.fetch("NAMECHEAP_EMAIL", "christian@gen.co"),
    }

    doc = api_call("namecheap.domains.create", params)

    result = doc.at_css("DomainCreateResult")
    {
      domain: result["Domain"],
      registered: result["Registered"] == "true",
      charged: result["ChargedAmount"],
      order_id: result["OrderID"],
      transaction_id: result["TransactionID"]
    }
  end

  # Returns an array of hashes with DNS host records:
  #   { host_id:, hostname:, type:, address:, mx_pref:, ttl:, is_active: }
  def dns_records(domain)
    parts = domain.split(".")
    sld = parts[0..-2].join(".")
    tld = parts[-1]

    doc = api_call("namecheap.domains.dns.getHosts", {
      "SLD" => sld,
      "TLD" => tld
    })

    doc.css("DomainDNSGetHostsResult host").map do |node|
      {
        host_id: node["HostId"],
        hostname: node["Name"],
        type: node["Type"],
        address: node["Address"],
        mx_pref: node["MXPref"],
        ttl: node["TTL"],
        is_active: node["IsActive"] == "true"
      }
    end
  end

  # Sets DNS host records for a domain. Pass an array of hashes:
  #   [{ hostname:, type:, address:, mx_pref: "10", ttl: "1800" }, ...]
  # NOTE: This REPLACES all records — you must include every record you want to keep.
  def set_dns_records(domain, records)
    parts = domain.split(".")
    sld = parts[0..-2].join(".")
    tld = parts[-1]

    params = { "SLD" => sld, "TLD" => tld }

    records.each_with_index do |record, i|
      n = i + 1
      params["HostName#{n}"] = record[:hostname] || "@"
      params["RecordType#{n}"] = record[:type] || "A"
      params["Address#{n}"] = record[:address]
      params["MXPref#{n}"] = record.fetch(:mx_pref, "10")
      params["TTL#{n}"] = record.fetch(:ttl, "1800")
    end

    api_call("namecheap.domains.dns.setHosts", params)
  end

  # Submit a domain transfer request.
  # Requires an EPP/auth code from the current registrar.
  # Returns: { domain:, transfer:, transfer_id:, status_id:, order_id:, transaction_id:, charged:, status_code: }
  def transfer_create(domain, epp_code, years: 1)
    params = {
      "DomainName" => domain,
      "Years" => years.to_s,
      "EPPCode" => epp_code,
      "AddFreeWhoisguard" => "yes",
      "WGEnabled" => "yes",
      # Registrant info
      "RegistrantFirstName" => ENV.fetch("NAMECHEAP_FIRST_NAME", "Christian"),
      "RegistrantLastName" => ENV.fetch("NAMECHEAP_LAST_NAME", "Genco"),
      "RegistrantAddress1" => ENV.fetch("NAMECHEAP_ADDRESS", "2028 E Ben White Blvd #240-8529"),
      "RegistrantCity" => ENV.fetch("NAMECHEAP_CITY", "Austin"),
      "RegistrantStateProvince" => ENV.fetch("NAMECHEAP_STATE", "TX"),
      "RegistrantPostalCode" => ENV.fetch("NAMECHEAP_ZIP", "78741"),
      "RegistrantCountry" => ENV.fetch("NAMECHEAP_COUNTRY", "US"),
      "RegistrantPhone" => ENV.fetch("NAMECHEAP_PHONE", "+1.5555555555"),
      "RegistrantEmailAddress" => ENV.fetch("NAMECHEAP_EMAIL", "christian@gen.co"),
      # Tech contact
      "TechFirstName" => ENV.fetch("NAMECHEAP_FIRST_NAME", "Christian"),
      "TechLastName" => ENV.fetch("NAMECHEAP_LAST_NAME", "Genco"),
      "TechAddress1" => ENV.fetch("NAMECHEAP_ADDRESS", "2028 E Ben White Blvd #240-8529"),
      "TechCity" => ENV.fetch("NAMECHEAP_CITY", "Austin"),
      "TechStateProvince" => ENV.fetch("NAMECHEAP_STATE", "TX"),
      "TechPostalCode" => ENV.fetch("NAMECHEAP_ZIP", "78741"),
      "TechCountry" => ENV.fetch("NAMECHEAP_COUNTRY", "US"),
      "TechPhone" => ENV.fetch("NAMECHEAP_PHONE", "+1.5555555555"),
      "TechEmailAddress" => ENV.fetch("NAMECHEAP_EMAIL", "christian@gen.co"),
      # Admin contact
      "AdminFirstName" => ENV.fetch("NAMECHEAP_FIRST_NAME", "Christian"),
      "AdminLastName" => ENV.fetch("NAMECHEAP_LAST_NAME", "Genco"),
      "AdminAddress1" => ENV.fetch("NAMECHEAP_ADDRESS", "2028 E Ben White Blvd #240-8529"),
      "AdminCity" => ENV.fetch("NAMECHEAP_CITY", "Austin"),
      "AdminStateProvince" => ENV.fetch("NAMECHEAP_STATE", "TX"),
      "AdminPostalCode" => ENV.fetch("NAMECHEAP_ZIP", "78741"),
      "AdminCountry" => ENV.fetch("NAMECHEAP_COUNTRY", "US"),
      "AdminPhone" => ENV.fetch("NAMECHEAP_PHONE", "+1.5555555555"),
      "AdminEmailAddress" => ENV.fetch("NAMECHEAP_EMAIL", "christian@gen.co"),
      # Aux billing contact
      "AuxBillingFirstName" => ENV.fetch("NAMECHEAP_FIRST_NAME", "Christian"),
      "AuxBillingLastName" => ENV.fetch("NAMECHEAP_LAST_NAME", "Genco"),
      "AuxBillingAddress1" => ENV.fetch("NAMECHEAP_ADDRESS", "2028 E Ben White Blvd #240-8529"),
      "AuxBillingCity" => ENV.fetch("NAMECHEAP_CITY", "Austin"),
      "AuxBillingStateProvince" => ENV.fetch("NAMECHEAP_STATE", "TX"),
      "AuxBillingPostalCode" => ENV.fetch("NAMECHEAP_ZIP", "78741"),
      "AuxBillingCountry" => ENV.fetch("NAMECHEAP_COUNTRY", "US"),
      "AuxBillingPhone" => ENV.fetch("NAMECHEAP_PHONE", "+1.5555555555"),
      "AuxBillingEmailAddress" => ENV.fetch("NAMECHEAP_EMAIL", "christian@gen.co"),
    }

    doc = api_call("namecheap.domains.transfer.create", params)

    result = doc.at_css("DomainTransferCreateResult")
    {
      domain: result["Domainname"],
      transfer: result["Transfer"] == "true",
      transfer_id: result["TransferID"],
      status_id: result["StatusID"],
      order_id: result["OrderID"],
      transaction_id: result["TransactionID"],
      charged: result["ChargedAmount"],
      status_code: result["StatusCode"]
    }
  end

  # Get the status of a particular transfer.
  # Returns: { transfer_id:, status:, status_id: }
  def transfer_get_status(transfer_id)
    doc = api_call("namecheap.domains.transfer.getStatus", {
      "TransferID" => transfer_id.to_s
    })

    result = doc.at_css("DomainTransferGetStatusResult")
    {
      transfer_id: result["TransferID"],
      status: result["Status"],
      status_id: result["StatusID"]
    }
  end

  # List domain transfers.
  # Options: page, page_size, list_type (ALL, INPROGRESS, CANCELLED, COMPLETED), search_term
  # Returns: array of transfer records
  def transfer_get_list(page: 1, page_size: 100, list_type: nil, search_term: nil)
    params = {
      "Page" => page.to_s,
      "PageSize" => page_size.to_s
    }
    params["ListType"] = list_type if list_type
    params["SearchTerm"] = search_term if search_term

    doc = api_call("namecheap.domains.transfer.getList", params)

    doc.css("TransferGetListResult Transfer").map do |node|
      {
        transfer_id: node["ID"],
        domain: node["DomainName"],
        user: node["User"],
        transfer_date: node["TransferDate"],
        order_id: node["OrderID"],
        status_id: node["StatusID"],
        status: node["Status"],
        status_date: node["StatusDate"],
        status_description: node["StatusDescription"]
      }
    end
  end

  # Sets custom nameservers for a domain (e.g., for Cloudflare)
  def set_nameservers(domain, nameservers)
    parts = domain.split(".")
    sld = parts[0..-2].join(".")
    tld = parts[-1]

    api_call("namecheap.domains.dns.setCustom", {
      "SLD" => sld,
      "TLD" => tld,
      "Nameservers" => nameservers.join(",")
    })
  end

  private

  def detect_ip
    uri = URI("https://api.ipify.org")
    Net::HTTP.get(uri).strip
  end

  def api_call(command, extra_params = {})
    params = {
      "ApiUser" => @username,
      "ApiKey" => @api_key,
      "UserName" => @username,
      "ClientIp" => @client_ip,
      "Command" => command
    }.merge(extra_params)

    uri = URI(API_URL)
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)

    unless response.is_a?(Net::HTTPSuccess)
      raise "HTTP #{response.code}: #{response.body}"
    end

    doc = Nokogiri::XML(response.body)

    status = doc.at_css("ApiResponse")&.attr("Status")
    if status != "OK"
      errors = doc.css("Errors Error").map(&:text)
      raise "Namecheap API error: #{errors.join('; ')}"
    end

    doc
  end
end
