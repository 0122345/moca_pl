# Generates CSV files from INSERT statements in db/scripts/db.schema.sql
# Outputs CSVs into exports/ for: users, drivers, rides, payments, messages, tracking, driver_ratings, ride_requests_log

param(
  [string]$SchemaPath = "db/scripts/db.schema.sql",
  [string]$OutDir = "exports"
)

$ErrorActionPreference = 'Stop'

# Column definitions (in table order)
$columns = @{
  'users' = @('user_id','full_name','email','phone','role','password_hash','jwt_token','created_at')
  'drivers' = @('driver_id','user_id','license_no','vehicle_type','vehicle_plate','rating','is_available','total_rides')
  'rides' = @('ride_id','rider_id','driver_id','pickup_location','dropoff_location','pickup_latitude','pickup_longitude','dropoff_latitude','dropoff_longitude','fare_amount','payment_method','status','updated_at','requested_at','started_at','completed_at','distance_km','duration_minutes')
  'payments' = @('payment_id','ride_id','amount','method','transaction_ref','is_successful','timestamp','payment_details')
  'messages' = @('message_id','sender_id','receiver_id','ride_id','message_body','is_read','sent_at')
  'tracking' = @('tracking_id','driver_id','ride_id','latitude','longitude','speed','heading','timestamp')
  'driver_ratings' = @('rating_id','ride_id','driver_id','rider_id','rating','rating_comment','rated_at')
  'ride_requests_log' = @('log_id','rider_id','pickup_location','dropoff_location','vehicle_type','requested_at','was_matched','time_to_match_seconds')
}

# Initialize sequences (based on schema starts)
$seq = @{
  'users_seq' = 1001
  'drivers_seq' = 2001
  'rides_seq' = 3001
  'payments_seq' = 4001
  'messages_seq' = 5001
  'tracking_seq' = 6001
  'ratings_seq' = 7001
  'log_seq' = 8001
  'tracking_history_seq' = 9001
}

$rowsByTable = @{}
foreach ($t in $columns.Keys) { $rowsByTable[$t] = New-Object System.Collections.ArrayList }

function Split-SqlValues {
  param([string]$s)
  $vals = @()
  $buf = ''
  $inQuote = $false
  for ($i=0; $i -lt $s.Length; $i++) {
    $ch = $s[$i]
    if ($ch -eq "'") {
      if ($inQuote -and ($i+1 -lt $s.Length) -and $s[$i+1] -eq "'") {
        # Escaped single quote within a string literal
        $buf += "''"
        $i++
      } else {
        $inQuote = -not $inQuote
        $buf += $ch
      }
    } elseif ($ch -eq ',' -and -not $inQuote) {
      $vals += $buf.Trim()
      $buf = ''
    } else {
      $buf += $ch
    }
  }
  if ($buf -ne '') { $vals += $buf.Trim() }
  return ,$vals
}

function Normalize-Value {
  param([string]$token)
  if ($null -eq $token) { return $null }
  $tok = $token.Trim()

  # Sequence NEXTVAL
  $m = [regex]::Match($tok, '^(?<base>[A-Za-z_][A-Za-z0-9_]*)_seq\.NEXTVAL$')
  if ($m.Success) {
    $key = $m.Groups['base'].Value + '_seq'
    if (-not $seq.ContainsKey($key)) { throw "Unknown sequence: $key" }
    $val = $seq[$key]
    $seq[$key] = $seq[$key] + 1
    return $val
  }

  # TIMESTAMP 'YYYY-MM-DD HH24:MI:SS'
  $m2 = [regex]::Match($tok, "^TIMESTAMP\s*'(?<ts>[^']*)'$")
  if ($m2.Success) { return $m2.Groups['ts'].Value }

  # CURRENT_TIMESTAMP -> render now in 'yyyy-MM-dd HH:mm:ss'
  if ($tok -ieq 'CURRENT_TIMESTAMP') { return (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') }

  # NULL
  if ($tok -ieq 'NULL') { return $null }

  # Quoted string literal -> unquote and unescape doubled quotes
  $m3 = [regex]::Match($tok, "^'(.*)'$")
  if ($m3.Success) {
    $str = $m3.Groups[1].Value -replace "''", "'"
    return $str
  }

  # Numeric
  if ($tok -match '^[+-]?[0-9]+(\.[0-9]+)?$') { return [decimal]::Parse($tok, [System.Globalization.CultureInfo]::InvariantCulture) }

  # Fallback: raw token
  return $tok
}

# Read schema
if (-not (Test-Path -LiteralPath $SchemaPath)) { throw "Schema file not found: $SchemaPath" }
$lines = Get-Content -LiteralPath $SchemaPath -Encoding UTF8

$insertRegex = '^[\s]*INSERT\s+INTO\s+([A-Za-z_][A-Za-z0-9_]*)\s*(\(([^)]*)\))?\s+VALUES\s*\((.*)\)\s*;\s*$'

foreach ($line in $lines) {
  $m = [regex]::Match($line, $insertRegex)
  if (-not $m.Success) { continue }
  $table = $m.Groups[1].Value.ToLower()
  if (-not $columns.ContainsKey($table)) { continue }

  $colListStr = $m.Groups[3].Value
  $valsStr = $m.Groups[4].Value

  $cols = @()
  if ($colListStr -and $colListStr.Trim().Length -gt 0) {
    $cols = $colListStr.Split(',') | ForEach-Object { $_.Trim().Trim('"').Trim() }
  } else {
    $cols = $columns[$table]
  }

  $tokens = Split-SqlValues -s $valsStr
  if ($tokens.Count -ne $cols.Count) {
    throw "Column/value count mismatch for table $table. Cols: $($cols.Count) Values: $($tokens.Count) Line: $line"
  }

  # Build map col->value
  $rowMap = @{}
  for ($i=0; $i -lt $cols.Count; $i++) {
    $c = $cols[$i]
    $v = Normalize-Value -token $tokens[$i]
    $rowMap[$c] = $v
  }

  # Build ordered object in table's canonical column order
  $ordered = [ordered]@{}
  foreach ($hc in $columns[$table]) {
    if ($rowMap.ContainsKey($hc)) { $ordered[$hc] = $rowMap[$hc] } else { $ordered[$hc] = $null }
  }

  $null = $rowsByTable[$table].Add([PSCustomObject]$ordered)
}

# Ensure output directory exists
if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }

# Export CSVs
foreach ($kv in $rowsByTable.GetEnumerator()) {
  $t = $kv.Key
  $rows = $kv.Value
  if ($rows.Count -gt 0) {
    $outPath = Join-Path $OutDir ("$t.csv")
    $rows | Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8
    Write-Host "Exported $($rows.Count) rows to $outPath"
  }
}

Write-Host "Done. CSVs available under: $OutDir"