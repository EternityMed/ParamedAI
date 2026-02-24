Get-Process | Where-Object { $_.Path -like '*Android*' -or $_.ProcessName -like '*emulator*' -or $_.ProcessName -like '*qemu*' } | Select-Object Id,ProcessName,Path | Format-Table -AutoSize
