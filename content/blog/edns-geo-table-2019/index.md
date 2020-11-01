---
title: Testing CDNs for best country specific results with different DNS providers
date: "2019-05-06T22:50Z"
description: "Testing CDNs for best country specific results with different DNS providers"
draft: false
---

<style>
table, th, td {
  border: 1px solid black;
}
</style>
<table style="height: 247px;" width="738">
<tbody>
<tr style="height: 65px;">
<td style="width: 109.357px; height: 65px;"><strong>DNS / Site</strong></td>
<td style="width: 80.9739px; height: 65px;"><strong>EDNS</strong></td>
<td style="width: 90.1565px; height: 65px;"><strong>Akamai</strong></td>
<td style="width: 86.8174px; height: 65px;"><strong>Google</strong></td>
<td style="width: 86.8174px; height: 65px;"><strong>Netilify</strong></td>
<td style="width: 70.9565px; height: 65px;"><strong>Cloudfront</strong></td>
<td style="width: 79.3044px; height: 65px;"><strong>Fastly</strong></td>
<td style="width: 113.53px; height: 65px;"><strong>BunnyCDN</strong></td>
</tr>
<tr style="height: 46.7391px;">
<td style="width: 109.357px; height: 46.7391px;"><strong>Cloudflare</strong></td>
<td class="align-center" style="width: 80.9739px; height: 46.7391px;">❌ </td>
<td style="width: 90.1565px; height: 46.7391px;">France</td>
<td style="width: 86.8174px; height: 46.7391px;">France</td>
<td style="width: 86.8174px; height: 46.7391px;">Germany</td>
<td style="width: 70.9565px; height: 46.7391px;">Italy</td>
<td style="width: 79.3044px; height: 46.7391px;">France </td>
<td style="width: 113.53px; height: 46.7391px;">France </td>
</tr>
<tr style="height: 45px;">
<td style="width: 109.357px; height: 45px;"><strong>Google</strong></td>
<td class="align-center" style="width: 80.9739px; height: 45px;">✔️</td>
<td style="width: 90.1565px; height: 45px;">Sri Lanka</td>
<td style="width: 86.8174px; height: 45px;">India</td>
<td style="width: 86.8174px; height: 45px;">Singapore</td>
<td style="width: 70.9565px; height: 45px;">Singapore</td>
<td style="width: 79.3044px; height: 45px;">France </td>
<td style="width: 113.53px; height: 45px;">Singapore</td>
</tr>
<tr style="height: 45px;">
<td style="width: 109.357px; height: 45px;"><strong>Quad9</strong></td>
<td class="align-center" style="width: 80.9739px; height: 45px;">❌</td>
<td style="width: 90.1565px; height: 45px;">Singapore</td>
<td style="width: 86.8174px; height: 45px;">Singapore</td>
<td style="width: 86.8174px; height: 45px;">Singapore</td>
<td style="width: 70.9565px; height: 45px;">Singapore</td>
<td style="width: 79.3044px; height: 45px;">Singapore</td>
<td style="width: 113.53px; height: 45px;">Singapore</td>
</tr>
<tr style="height: 45px;">
<td style="width: 109.357px; height: 45px;"><strong>OpenDNS</strong></td>
<td class="align-center" style="width: 80.9739px; height: 45px;">✔️</td>
<td style="width: 90.1565px; height: 45px;">Sri Lanka</td>
<td style="width: 86.8174px; height: 45px;">India</td>
<td style="width: 86.8174px; height: 45px;">Singapore</td>
<td style="width: 70.9565px; height: 45px;">Singapore</td>
<td style="width: 79.3044px; height: 45px;">France </td>
<td style="width: 113.53px; height: 45px;">Singapore</td>
</tr>
</tbody>
</table>

  
All tests are conducted on IPv4 and from Sri Lanka.  (AS[18001](https://db-ip.com/as18001))

Overall Google and OpenDNS, which support EDNS seems the best.