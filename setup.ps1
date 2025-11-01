param(
    [Parameter(Mandatory=$true)]
    [string[]]$Args
)

if ($Args.Count -lt 5) {
    Write-Host "用法: script.ps1 用户 仓库 分支 文件 可执行程序 [重复多组]"
    exit 1
}

function Download-Release {
    param(
        [string]$User,
        [string]$Repo,
        [string]$Branch,
        [string]$File,
        [string]$Exe
    )

    Write-Host "下载 $Exe ..."

    $MAX_RETRIES = 3
    $RETRY_COUNT = 0
    $Success = $false

    while ($RETRY_COUNT -lt $MAX_RETRIES -and -not $Success) {
        try {
            Invoke-WebRequest -Uri "https://github.com/$User/$Repo/releases/download/$Branch/$File" -OutFile $File -UseBasicParsing
            if ((Test-Path $File) -and ((Get-Item $File).Length -gt 0)) { $Success = $true } else { throw "文件为空" }
        } catch {
            $RETRY_COUNT++
            Write-Host "下载失败，重试 $RETRY_COUNT/$MAX_RETRIES..."
            Start-Sleep -Seconds 2
        }
    }

    if (-not $Success) {
        Write-Host "下载 $File 失败，跳过 $Exe"
        return
    }

    try {
        if ($File -match '\.tar\.gz$') { tar -xzf $File } 
        elseif ($File -match '\.zip$') { Expand-Archive -Path $File -DestinationPath . -Force }
        Remove-Item $File
    } catch {
        Write-Host "解压 $File 失败: $_"
    }

    Write-Host "$Exe 获取成功！"
}

# 并行任务数组
$jobs = @()

for ($i = 0; $i -le $Args.Count - 5; $i += 5) {
    $U = $Args[$i]; $P = $Args[$i+1]; $B = $Args[$i+2]; $F = $Args[$i+3]; $E = $Args[$i+4]

    $jobs += Start-Job -ScriptBlock {
        param($U,$P,$B,$F,$E)
        function Download-Release {
            param($User,$Repo,$Branch,$File,$Exe)
            Write-Host "下载 $Exe ..."
            $MAX_RETRIES = 3
            $RETRY_COUNT = 0
            $Success = $false
            while ($RETRY_COUNT -lt $MAX_RETRIES -and -not $Success) {
                try {
                    Invoke-WebRequest -Uri "https://github.com/$User/$Repo/releases/download/$Branch/$File" -OutFile $File -UseBasicParsing
                    if ((Test-Path $File) -and ((Get-Item $File).Length -gt 0)) { $Success = $true } else { throw "文件为空" }
                } catch {
                    $RETRY_COUNT++
                    Write-Host "下载失败，重试 $RETRY_COUNT/$MAX_RETRIES..."
                    Start-Sleep -Seconds 2
                }
            }
            if (-not $Success) { Write-Host "下载 $File 失败，跳过 $Exe"; return }
            try {
                if ($File -match '\.tar\.gz$') { tar -xzf $File } 
                elseif ($File -match '\.zip$') { Expand-Archive -Path $File -DestinationPath . -Force }
                Remove-Item $File
            } catch { Write-Host "解压 $File 失败: $_" }
            Write-Host "$Exe 获取成功！"
        }
        Download-Release -User $U -Repo $P -Branch $B -File $F -Exe $E
    } -ArgumentList $U,$P,$B,$F,$E
}

# 等待所有任务完成
$jobs | Wait-Job
$jobs | Receive-Job
$jobs | Remove-Job
