# tests/hooks/guard-taboos/windows.sh — Windows, as WSL and SSH reach it.
# Sourced by tests/hooks/guard-taboos.sh, in its order, into the
# one shell every part shares; never run on its own.
# shellcheck shell=sh

# --- Windows, as WSL reaches it --------------------------------
check deny 'shutdown.exe /s /t 0'
check deny 'shutdown.exe -s -t 0'
check deny 'Shutdown.exe /s /t 0'
check deny 'SHUTDOWN.EXE /p'
check deny 'shutdown -h now /r'
check deny 'shutdown -h now -a'
check deny 'MBR2GPT.EXE /convert'
check deny 'powershell.exe -Command Stop-Computer'
check deny 'pwsh.exe -c "stop-computer -Force"'
check deny 'wsl.exe --shutdown'
check deny 'wsl --terminate Ubuntu'
check deny 'WSL.EXE -t Ubuntu'
check deny 'wsl.exe --unregister Ubuntu'
check deny 'wslconfig.exe /t Ubuntu'
check deny 'wslconfig.exe /unregister Ubuntu'
check deny 'WslConfig /u Ubuntu'
check deny '"wsl.exe" --unregister Ubuntu'
check deny '"/mnt/c/Windows/System32/wsl.exe" --shutdown'
check deny 'cmd.exe /c format "D:" /q'
check deny 'rm -rf /mnt/c/ProgramData/ssh'
check deny 'chmod -R 000 /mnt/c/ProgramData/ssh/'
check deny 'echo x > /mnt/c/ProgramData/ssh/SSHD_CONFIG'
check deny ': > /mnt/c/ProgramData/ssh/SSH_HOST_ED25519_KEY'
check deny 'echo ssh-ed25519 AAAA >> /mnt/c/ProgramData/ssh/Administrators_Authorized_Keys'
check deny 'diskpart'
check deny 'diskpart.exe /s wipe.txt'
check deny 'powershell.exe -c "Clear-Disk -Number 1 -RemoveData"'
check deny 'powershell.exe -c "Get-Disk 1 | Initialize-Disk -PartitionStyle GPT"'
check deny 'pwsh.exe -c "Format-Volume -DriveLetter D"'
check deny 'powershell.exe -c "Remove-Partition -DiskNumber 1 -PartitionNumber 2"'
check deny 'powershell.exe -c "Resize-Partition -DriveLetter C -Size 100GB"'
check deny 'mbr2gpt.exe /convert /allowFullOS'
check deny 'cmd.exe /c format D: /q'
check deny 'powershell.exe -c "Set-Content \\.\PhysicalDrive1 -Value 0"'
check deny 'cp image.bin //./PhysicalDrive1'
check deny 'powershell.exe -c "Remove-Item C:\ProgramData\ssh\ssh_host_ed25519_key"'
check deny 'powershell.exe -c "Add-Content C:\ProgramData\ssh\sshd_config Port"'
check deny 'echo PasswordAuthentication no >> /mnt/c/ProgramData/ssh/sshd_config'
check deny 'rm /mnt/c/ProgramData/ssh/ssh_host_rsa_key'
check deny 'rm /mnt/c/programdata/ssh/ssh_host_rsa_key'
check deny 'pwsh.exe -c "Remove-Item $HOME\.ssh\id_ed25519"'
check deny 'powershell.exe -c "Set-Content C:\ProgramData\ssh\administrators_authorized_keys x"'
# Over SSH a Windows server runs cmd and PowerShell verbs without
# either being named.
check deny 'ssh host "del C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "ERASE C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "del /f /q C:\ProgramData\ssh\ssh_host_ed25519_key"'
check deny "ssh host 'del \"C:\\ProgramData\\ssh\\sshd_config\"'"
check deny 'ssh host "rd /s /q C:\ProgramData\ssh"'
check deny 'ssh host "move C:\ProgramData\ssh\sshd_config C:\tmp\x"'
check deny 'ssh host "ren C:\ProgramData\ssh\sshd_config old"'
check deny 'ssh host "copy /y C:\tmp\x C:\ProgramData\ssh\ssh_host_ed25519_key"'
check deny 'ssh host "xcopy C:\tmp\x C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "takeown /f C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "attrib +r C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "icacls C:\ProgramData\ssh\ssh_host_ed25519_key /grant Users:F"'
check deny 'ssh host "icacls C:\ProgramData\ssh\sshd_config /reset"'
check deny 'ssh host "Remove-Item -Recurse -Force C:\ProgramData\ssh"'
check deny 'ssh host "ri C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "Move-Item C:\ProgramData\ssh\sshd_config C:\tmp"'
check deny 'ssh host "Rename-Item C:\ProgramData\ssh\sshd_config old"'
check deny 'ssh host "Set-Content C:\ProgramData\ssh\sshd_config x"'
check deny 'ssh host "Clear-Content C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "Copy-Item C:\tmp\x C:\ProgramData\ssh\sshd_config"'
check deny 'ssh host "gci C:\ProgramData\ssh\ssh_host_* | ri"'
check deny 'ssh host "Get-ChildItem C:\ProgramData\ssh | Remove-Item -Force"'
check deny 'del /mnt/c/ProgramData/ssh/sshd_config'
check pass 'ssh host "type C:\ProgramData\ssh\sshd_config"'
check pass 'ssh host "Get-Content C:\ProgramData\ssh\sshd_config"'
check pass 'ssh host "dir C:\ProgramData\ssh"'
check pass 'ssh host "icacls C:\ProgramData\ssh\ssh_host_ed25519_key"'
check pass 'ssh host "findstr Port C:\ProgramData\ssh\sshd_config"'
check pass 'ssh host "Get-Acl C:\ProgramData\ssh\sshd_config | Format-List"'
check pass 'ssh host "Get-Service sshd; Get-Content C:\ProgramData\ssh\sshd_config"'
check pass 'ssh host "del C:\ProgramData\ssh-backups\old.txt"'
check pass 'ssh host "Set-Content C:\ProgramData\ssh_notes\report.txt x"'
check pass 'ssh host "del C:\ProgramData\ssh.old\report.txt"'
check pass 'ssh host "dir C:\ProgramData\ssh>NUL"'
# The directory followed by the shell's punctuation is still it.
check deny 'ssh host "rd /s /q C:\ProgramData\ssh>NUL"'
check deny 'ssh host "(Remove-Item -Recurse -Force C:\ProgramData\ssh)"'
check deny 'ssh host "gci C:\ProgramData\ssh| ri"'
check pass 'shutdown.exe /r /t 0'
check pass 'shutdown.exe /a'
check pass 'Shutdown.exe -r -t 0'
check pass 'MBR2GPT.EXE /Validate /AllowFullOS'
check pass 'powershell.exe -c Restart-Computer'
check pass 'wsl.exe --list --verbose'
check pass 'wslconfig.exe /l'
check pass 'wsl.exe -u root -e apt-get update'
check pass 'wsl.exe -d Ubuntu -- ls -t /var/log'
check pass 'powershell.exe -c "Get-Disk; Get-Partition; Get-Volume"'
check pass 'mbr2gpt.exe /validate /allowFullOS'
check pass 'cat /mnt/c/ProgramData/ssh/sshd_config'
check pass 'ls -l /mnt/c/ProgramData/ssh/'
check pass 'date +%Y-%m-%d --date=yesterday'
check pass 'git log --format="%h %s" -5'

# --- Windows Server, as SSH reaches it -------------------------
# The shape the Windows rules send: PowerShell in the body of a
# heredoc, which the guard scans because pwsh executes it.
PS_SSH='ssh -o BatchMode=yes -o ConnectTimeout=5 administrator@win1.example.com '\''pwsh -NoProfile -NonInteractive -Command -'\'' <<'\''EOS'\''
'
check deny 'shutdown /s /t 0'
check deny 'shutdown /p'
check deny 'shutdown /h'
check deny 'SHUTDOWN /P /F'
check deny 'shutdown /sg /t 0'
check deny 'shutdown.exe /h'
check deny 'shutdown /r /p'
check deny 'shutdown.exe /r /s'
check deny 'shutdown /r -h now'
check deny 'ssh administrator@win1.example.com shutdown /s /t 0'
check deny "${PS_SSH}shutdown /p
EOS"
check deny 'bcdedit /set {default} safeboot minimal'
check deny 'bcdedit /deletevalue {default} safeboot'
check deny 'bcdedit /v /set {default} testsigning on'
check deny 'bcdedit /enum; bcdedit /delete {ntldr}'
check deny 'BCDEdit.exe /default {current}'
check deny 'bcdedit /import C:\bcd.bak'
check deny 'C:\Windows\System32\bcdedit.exe /timeout 0'
check deny 'ssh administrator@win1.example.com "bcdedit /enum && bcdedit /bootsequence {fwbootmgr}"'
check deny "${PS_SSH}bcdedit /enum all
bcdedit /set {current} recoveryenabled No
EOS"
check deny 'cipher /w:C:\'
check deny 'cipher.exe /W:D:\data'
check deny 'cmd.exe /c "cipher /w:C:\temp"'
check deny "${PS_SSH}cipher /w:C:\\
EOS"
check deny 'powershell.exe -c "Remove-VirtualDisk Data01"'
check deny "${PS_SSH}Remove-VirtualDisk -FriendlyName Data01 -Confirm:\$false
EOS"
check deny "${PS_SSH}Get-StoragePool -FriendlyName Pool1 | Remove-StoragePool
EOS"
check deny "${PS_SSH}Get-Disk 1 | Clear-Disk -RemoveData
EOS"
check deny "${PS_SSH}Stop-Computer -Force
EOS"
check deny "${PS_SSH}Set-Content C:\\ProgramData\\ssh\\sshd_config 'Port 22'
EOS"
# A quote or backtick is dropped before the program sees its flag.
check deny 'bcdedit "/set" {default} safeboot minimal'
check deny 'bcdedit `/set {default} safeboot minimal'
check deny "bcdedit /enum '/delete' {ntldr}"
check deny 'cipher "/w:C:\"'
check deny "cipher.exe '/w' C:\\"
check deny 'shutdown /r "-h" now'
check deny 'shutdown /r "/p"'
check deny 'shutdown.exe /r "/s"'
check pass 'shutdown /r /t 0 /c "planned restart"'
check pass 'bcdedit /store "C:\Boot\BCD" /enum'
check pass 'shutdown /r /t 0'
check pass 'shutdown /g /t 0'
check pass 'shutdown /a'
check pass 'ssh administrator@win1.example.com shutdown /r /t 0'
check pass "${PS_SSH}shutdown /r /t 60 /d p:2:17
EOS"
check pass "${PS_SSH}Restart-Computer -Force
EOS"
check pass 'shutdown -r now'
check pass 'bcdedit'
check pass 'bcdedit /enum'
check pass 'bcdedit /enum all /v'
check pass 'bcdedit.exe /enum {current}'
check pass 'BCDEDIT /V'
check pass 'bcdedit /store C:\Boot\BCD /enum'
check pass 'ssh administrator@win1.example.com "bcdedit /enum active" 2>&1 | head -20'
check pass "${PS_SSH}bcdedit /enum firmware | Out-String
EOS"
check pass 'cipher'
check pass 'cipher /c secret.txt'
check pass 'cipher /u /n'
check pass "${PS_SSH}Get-Disk
Get-Partition
Get-Volume
Get-VirtualDisk
Get-StoragePool
EOS"
check pass 'ssh administrator@win1.example.com '\''cmd /c ver'\'''
# The OpenSSH DefaultShell value is Hostwarden's to set once the
# user approves; it is not a taboo.
check pass "${PS_SSH}Get-ItemProperty -Path HKLM:\\SOFTWARE\\OpenSSH -Name DefaultShell
EOS"
check pass "${PS_SSH}New-ItemProperty -Path HKLM:\\SOFTWARE\\OpenSSH -Name DefaultShell -Value 'C:\\Program Files\\PowerShell\\7\\pwsh.exe' -PropertyType String -Force
EOS"
