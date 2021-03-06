#TRUSTED 5265856a54cecc98d92637e9d6d69a4fb5a0f74e7492e3a1ee658f992ac40b91495e6c9f6b1beca3e480f09164bd140de82e6fad41c3201d72f777e479aa56423e687eeaa6c538245d95114ab9f66737178027818b0306e70dd451616250f149f200295850b27fdfab02ea69392bbdefb38cab26acd408f31da8a2c23dd9e631d9174251c051a6538153801bf6ae129c703ef53e9ccc7b9f4dd9833049d6e469a43e586cb11d302a08581aadb7737c7ea455208004f43e4e9ada1a77ae18f033d966bbf7f5ab7e327c0097b15cf54983f6908edd2470a32a8aa27be4ef3b9264db95c46daf52c5bdc86de456be70bf0a5a13d99b1b9526cc618a0c8672b1e44c0bb5dda637301d0ad7f5de6bc014f647a08f4d1ec9a037d4821250ee50564947c6427b97651fbb2ae9e6f8edadbac76c916b3c1f23489ba5202655246706ca1bb2ae4ec50518456677871717a1aae3fc1cab6f2f418bd8063474ef36c79414dda49803b41a44a6b382017b01c26f19f8a91668c8c486686bba43cc8f1e94fdcd1870d775785fcc00d51f0cea53e7a9533816ecf758c99fa6f77398b481ce7e12c39f2b21af5e677e3b3339c086ef23bfd8bb05f68ae617ca0c678f80bbf06d6c6e190f819ef97b6e4b3c3ef56244d7338d427f3561e0d2adb93de788fdd62c37be83c501a744aba2ee1eca0aac11c6d54944214ee2d070b9c57f6272fea5c2f6
#
# (C) Tenable Network Security, Inc.
#
# Nmap can be found at :
# <http://www.insecure.org/nmap/>
#
# ChangeLog:
#  2010/08/27: Reduced memory usage
#


if (! defined_func("xmlparse") ) exit(0);


include("compat.inc");

if(description)
{
 script_id(33818);
 script_version ("1.2");
 script_name(english:"Nmap (XML file importer)");
 
 script_set_attribute(attribute:"synopsis", value:
"Nmap XML file import." );
 script_set_attribute(attribute:"description", value:
"This plugin reads XML files that were generated by nmap -oX ...
It does not run Nmap." );
 script_set_attribute(attribute:"risk_factor", value:
"None" );
 script_set_attribute(attribute:"solution", value:
"n/a" );

script_end_attributes();

 
 script_summary(english: "Imports Nmap XML results");
 
 script_category(ACT_SCANNER);
 script_copyright(english:"This script is Copyright (C) 2009 - 2010 Tenable Network Security, Inc.");
 script_family(english: "Port scanners");

 script_dependencies("ping_host.nasl", "portscanners_settings.nasl");
 script_add_preference(name: "File containing XML results : ", value: "", type: "file");
 exit(0);
}

#

ip = get_host_ip();

res = script_get_preference_file_content("File containing XML results : ");
if (isnull(res) || strlen(res) == 0) exit(0);

if ('<?xml version="1.0"' >!< res )
  exit(1, "Result file does not like XML");


#
# Extract only the relevant section instead of parsing the entire XML file
#
idx = stridx(res, '<scaninfo');
if ( idx < 0 ) exit(1, "Malformed XML file");
idx2 = stridx(res, '<scaninfo', idx + strlen('<scaninfo'));
if ( idx2 >= 0 ) idx = idx2;
for ( i = idx; i < strlen(res) ; i ++ )
{
  if ( res[i] == '/' && res[i+1] == '>' ) break;
}
if ( i == strlen(res) ) exit(1, "Malformed XML file");
head = substr(res, 0, i + 1);

idx = stridx(res, '<address addr="' + ip + '"');
if ( idx < 0 ) exit(1, ip + ' not found in the nmap xml file');
for ( i = idx ; i >= 0 ; i -- )
{
 if ( substr(res, i, i + strlen("<host start") - 1) == "<host start") break;
}
if ( i < 0 ) exit(1, "Malformed XML file (1)");
start_idx = i;
idx = stridx(res, '</host>', start_idx + 1);
if ( idx < 0 ) exit(1, "Malformed XML file (2)");
idx += strlen('</host>');
res = substr(res, start_idx, idx);

# Reconstruct the XML
res = strcat(head, res, '</nmaprun>');


x = xmlparse(res);
if (isnull(x)) exit(1, "XML cannot be parsed");

y = x['attributes'];
if (y['scanner'] != 'nmap') exit(1, "Bad XML: scanner is not nmap");

x = x['children'];
if (isnull(x)) exit(1, "No children in top node");

full_scanned = make_array(); 
scanned = make_array(); 
found = 0;
for (i = 0; ! isnull(x[i]) && ! found; i ++)
{
  c = x[i];
  if (c['name'] == 'scaninfo')
  {
    a = c['attributes'];
    scanned[a['protocol']] = 1;
#    debug_print("numservices=", a['numservices'], '\tservices=', a['services'], '\n');
    if (a['numservices'] == 65535 && a['services'] == '1-65535')
      full_scanned[a['protocol']] = 1;
  }
  if (c['name'] == 'host')
  {
    if (decode_host_children(v: c['children']))
    {
      found ++; break;
    }
  }
}

if (found)
{
  if (scanned['tcp'])
  {
    set_kb_item(name: "Host/scanned", value: TRUE);
    set_kb_item(name: "Host/TCP/scanned", value: TRUE);
    if (full_scanned['tcp'])
    {
      set_kb_item(name: "Host/full_scan", value: TRUE);
      set_kb_item(name: "Host/TCP/full_scan", value: TRUE);
    }
  }
  if (scanned['udp'])
  {
    set_kb_item(name: "Host/UDP/scanned", value: TRUE);
    set_kb_item(name: "Host/udp_scanned", value: TRUE);
    if (full_scanned['udp'])
      set_kb_item(name: "Host/UDP/full_scan", value: TRUE);
  }
  set_kb_item(name: 'Host/scanners/nmap', value: TRUE);
}


function decode_host_children(v)
{
  local_var	i, w, a, z, j, p, c, k;
  local_var	found_ip, tcp_ports_l, udp_ports_l, tcp_ports_n, udp_ports_n;
  local_var	port_num, port_proto, port_state, scripts, service;

  found_ip = 0;
  tcp_ports_l = make_list();
  udp_ports_l = make_list();
  tcp_ports_n = 0; udp_ports_n = 0;

  for (i = 0; ! isnull(v[i]); i ++)
  {
    w = v[i];
    if (w['name'] == 'status')
    {
      a = w['attributes'];
      if (a['state'] != 'up')
      {
        #debug_print('Host is ', a['state'], '\n');
	return NULL;
      }
      # display("status: ", w['attributes'], '\n');
    }
    if (w['name'] == 'address')
    {
      a = w['attributes'];
      if (a['addrtype'] == 'ipv4' || a['addrtype'] == 'ipv6')
        if (a['addr'] == ip)
	  found_ip ++;
	else
	{
	  #debug_print('Found scan for ', a['addr'], '\n');
	  return NULL;
	}
      # display("address: ", w['attributes'], '\n');
    }

    if (w['name'] == 'ports')
    {
      scripts = ''; service = '';
      z = w['children'];
      for (j = 0; ! isnull(z[j]); j ++)
      {
        p = z[j];
	if (p['name'] == 'port')
	{
	  a = p['attributes'];
	  c = p['children'];
	  port_num = int(a['portid']);
	  port_proto = a['protocol'];
	  for (k = 0; ! isnull(c[k]); k ++)
	  {
	    a = c[k];
	    if (a['name'] == 'state')
	    {
	      a = a['attributes'];
	      port_state = a['state'];
	    }
	    if (a['name'] == 'service')
	    {
	      a = a['attributes'];
	      if (a['method'] == 'probed')
	      {
	        #debug_print("service=", a['name']);
		service = a['name'];
	      }
	    }
	    if (a['name'] == 'script')
	    {
	      a = a['attributes'];
	      scripts = strcat(scripts, a['id'], '\n', a['output'], '\n\n');
	    }
	  }
	}
	#debug_print(level: 2, port_num, '/', port_proto, '\t', port_state, '\n');
	if (port_num > 0 && port_state == 'open')
	 if (port_proto == 'tcp')
	   tcp_ports_l[tcp_ports_n ++] = port_num;
	 else if (port_proto == 'udp')
	   udp_ports_l[udp_ports_n ++] = port_num;
	 if (strlen(scripts) > 0)
	 {
	   security_note(port: port_num, proto: port_proto, data: scripts);
	   scripts = '';
	 }
	 if (strlen(service) > 0)
	 {
	   security_note(port: port_num, proto: port_proto, data: 'map has identified this service as '+service+'.\n');
	   set_kb_item(name: 'Nmap/'+port_proto+'/'+port_num+'/version', value: service);
	   service = '';
	 }
      }
    }
  }
  if (found_ip)
  {
    foreach p (tcp_ports_l) scanner_add_port(port: p, proto: 'tcp');
    foreach p (udp_ports_l) scanner_add_port(port: p, proto: 'udp');
    return 1;
  }
  return 0;    
}

