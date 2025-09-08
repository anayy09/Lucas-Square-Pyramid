param(
  [int]$N = 1000000,
  [int]$K = 4,
  [int]$Workers = 0, # 0 means auto-detect
  [int[]]$Units = @(1,10,100,1000,10000)
)

if ($Workers -le 0) {
  try {
    $Workers = (Get-CimInstance -ClassName Win32_ComputerSystem).NumberOfLogicalProcessors
  } catch {
    $Workers = 4
  }
}

Write-Host "Benchmarking lucas: N=$N K=$K Workers=$Workers"
Write-Host "Work units: $($Units -join ', ')"

$results = @()
foreach ($u in $Units) {
  $outFile = "bench_out_${N}_${K}_${Workers}_${u}.txt"
  Write-Host "Running work_unit=$u -> output: $outFile"

  $gleamArgs = "run $N $K $Workers $u"

  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $p = Start-Process -FilePath gleam -ArgumentList $gleamArgs -NoNewWindow -RedirectStandardOutput $outFile -PassThru -Wait
  $sw.Stop()

  # Get CPU time from process if available
  $cpuTime = $null
  try {
    $proc = Get-Process -Id $p.Id -ErrorAction Stop
    $cpuTime = $proc.TotalProcessorTime.TotalSeconds
  } catch {
    try { $cpuTime = $p.TotalProcessorTime.TotalSeconds } catch { $cpuTime = 0 }
  }

  $elapsed = $sw.Elapsed.TotalSeconds
  $ratio = 0
  if ($elapsed -gt 0) { $ratio = [math]::Round(($cpuTime / $elapsed), 4) }

  $results += [PSCustomObject]@{
    WorkUnit = $u
    ElapsedSeconds = [math]::Round($elapsed, 4)
    CPUSeconds = [math]::Round($cpuTime, 4)
    CPUtoReal = $ratio
    OutputFile = $outFile
  }
}

Write-Host "\nSummary:"
$results | Format-Table -AutoSize

# Save JSON for easy consumption
$results | ConvertTo-Json | Out-File bench_results.json -Encoding UTF8

Write-Host "Bench complete. Results saved to bench_results.json and output files for each run."
