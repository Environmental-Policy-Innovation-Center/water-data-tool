# How to Decode an Encoded URL Param

## Context

The `?encoded=` query param is a Zlib-compressed, URL-safe Base64 blob that carries filter state, column visibility, and table search. It is intentionally opaque in the browser — use this guide to inspect it during debugging or data investigation.

Full schema: `docs/decisions/URL_MANAGEMENT.md`

---

## Steps

### 1. Grab the `encoded` value from the URL

Example URL:
```
http://localhost:3001/?encoded=eJx9VcuS2zgM_Bed6SrZE29q5ppDjvmA1BaLQ0ISdvgKSdlRpfLv2yKVWDPx5GSiARFAown_6Aa2hVLunn50uahC3VP36UsnmiG9chUJNiRlAvDxKvNV6mBW_HMKszdXRCa4YohSqyLP3dPX7twfDw_ioe_hWH-Ph2Mv-mrWw2o34F_RsYuKExmZSyLlsnzoH4x07JHj1L3rV9_hP_bdT5RLKukJZglXjy90sOipi9fMRlBUMlEMqYhc5hyz0Ki7MGVxa0fkMCdNsnYjYwqFdOHgmxO3Ai1LJBETO6WXZnCW1ylYyspSWq2spxCsDEkatWiVasiYlC-SLI_8bJFpcc9gdFzkwGSNQJSS-RsaxkXiECJ5OZGyZZIXDlYcdoZaa8ryvCRxGG_0yzRbamie06B-N7ISVhwhfXVaUkYqb9BVjHBXEKPFpbO2bGi7mn1Io_KspZ7IsVZ2c-TFl4kKHO8EXGqNKOYdfwlFWaS3PITktkuLGkkepeHMfgDvoCvvXad7rj9ZOfZ3aWnwe7w071tiGvqamYbdo2bL8BduWsRfyGkBb9jZ7r1Lz973lp_miwqdXEN6-UM5dz37CnxAGxBjs_Cy5xYlbkdpyGcuyx6KuqAl5UcSbuK9GcOFUllkAvti9uSiDUvlvyKODCuoPsyZ8J6MZK-DI_GswBCWT0a2MRG16LVljHjV7w1YE8h_jg2IQbfDdeKyffVslX7Z4tdk9eRV5A3Lv8GJc6zjqVbAUKGkVTutVv6OVbSzQ0abwbnQPpfYLEls-lvtVurxdN6DMOXpw-MeOp17-eHxFXTue_nxddRHRD2-jqqtY5_24qDpP1QDNShzgRRAjFnHAKFcuMYpa1cAW0XvkKwDVtWhsIPOh7Vg80sKOQ1S5cxQmtf0C8UW9JojThDqyBfylLG7_OwkXhlbruv1AJk5xuobBjuvw77JbdtzlZv2YrHd8S-DSSLRC_yJ8wuWvAdUhRIt5rO__O7fQvfzf_e_kl8&sort=counties&direction=asc
```

Copy everything after `encoded=` up to the next `&`:
```
eJx9VcuS2zgM_Bed6SrZE29q5ppDjvm...
```

`sort` and `direction` are explicit params — they live outside the blob and do not need decoding.

### 2. Decode in the Rails console

```ruby
UrlStateCodec.decode("eJx9VcuS2zgM_Bed6SrZE29q5ppDjvmA1BaLQ0ISdvgKSdlRpfLv2yKVWDPx5GSiARFAown_6Aa2hVLunn50uahC3VP36UsnmiG9chUJNiRlAvDxKvNV6mBW_HMKszdXRCa4YohSqyLP3dPX7twfDw_ioe_hWH-Ph2Mv-mrWw2o34F_RsYuKExmZSyLlsnzoH4x07JHj1L3rV9_hP_bdT5RLKukJZglXjy90sOipi9fMRlBUMlEMqYhc5hyz0Ki7MGVxa0fkMCdNsnYjYwqFdOHgmxO3Ai1LJBETO6WXZnCW1ylYyspSWq2spxCsDEkatWiVasiYlC-SLI_8bJFpcc9gdFzkwGSNQJSS-RsaxkXiECJ5OZGyZZIXDlYcdoZaa8ryvCRxGG_0yzRbamie06B-N7ISVhwhfXVaUkYqb9BVjHBXEKPFpbO2bGi7mn1Io_KspZ7IsVZ2c-TFl4kKHO8EXGqNKOYdfwlFWaS3PITktkuLGkkepeHMfgDvoCvvXad7rj9ZOfZ3aWnwe7w071tiGvqamYbdo2bL8BduWsRfyGkBb9jZ7r1Lz973lp_miwqdXEN6-UM5dz37CnxAGxBjs_Cy5xYlbkdpyGcuyx6KuqAl5UcSbuK9GcOFUllkAvti9uSiDUvlvyKODCuoPsyZ8J6MZK-DI_GswBCWT0a2MRG16LVljHjV7w1YE8h_jg2IQbfDdeKyffVslX7Z4tdk9eRV5A3Lv8GJc6zjqVbAUKGkVTutVv6OVbSzQ0abwbnQPpfYLEls-lvtVurxdN6DMOXpw-MeOp17-eHxFXTue_nxddRHRD2-jqqtY5_24qDpP1QDNShzgRRAjFnHAKFcuMYpa1cAW0XvkKwDVtWhsIPOh7Vg80sKOQ1S5cxQmtf0C8UW9JojThDqyBfylLG7_OwkXhlbruv1AJk5xuobBjuvw77JbdtzlZv2YrHd8S-DSSLRC_yJ8wuWvAdUhRIt5rO__O7fQvfzf_e_kl8")
```

Output:
```ruby
{
  "filters" => {
    "state"                     => "CO",
    "state_name"                => "Colorado",
    "gw_sw_code"                => "Groundwater",
    "pop_cat_5"                 => ["501-3,300", "3,301-10,000", "10,001-100,000"],
    "impaired_streams_303d_min" => "2",
    "impaired_streams_303d_max" => "10"
  },
  "search" => "town",
  "cols"   => "pwsid,epa_report,stusps,counties,gw_sw_code,...,-impaired_streams_303d"
  #            ^^^^^^ plain key = visible    ^^^^^^^^^^^^^^^^^ -key = hidden
}
```

Keys present in the blob:

| Key | What it holds | When present |
|---|---|---|
| `"filters"` | Active filter params (see `config/filters.yml`) | When any filter is applied |
| `"search"` | Table search term | When table search is active |
| `"cols"` | Full column sequence — plain key = visible, `-key` = hidden | When columns differ from YAML default |

### 3. Decode without the Rails console (one-liner)

If you only have shell access:

```bash
echo "eJx9VcuS2zgM_Bed6SrZE29q5ppDjvm..." | ruby -r zlib -r base64 -r json -e \
  'puts JSON.pretty_generate(JSON.parse(Zlib::Inflate.inflate(Base64.urlsafe_decode64(STDIN.read.strip))))'
```

### 4. Encode a state (for testing or spec writing)

In the Rails console:
```ruby
require "zlib"
require "base64"
require "json"
Base64.urlsafe_encode64(Zlib::Deflate.deflate(JSON.generate({
  "filters" => { "state" => "CO", "state_name" => "Colorado", "gw_sw_code" => "Groundwater" },
  "search"  => "town"
})), padding: false)
```

In specs, use the `encode_state` helper (included automatically via `spec/support/url_state_codec_helpers.rb`):
```ruby
get table_path, params: { encoded: encode_state({ "search" => "town" }) }
get table_path, params: { encoded: encode_state({ "filters" => { "state" => "CO", "state_name" => "Colorado" } }) }
```
