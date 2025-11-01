param(
    [Parameter(Mandatory=$true)]
    [string[]]$Args
)

if ($Args.Count -lt 5) {
    Write-Host "用法: script.ps1 用户 仓库 分支 文件 可执行程序 [重复多组]"
    exit 1
}

# 当前目录
$cwd = Get-Location

# 并行任务数组
$jobs = @()

for ($i = 0; $i -le $Args.Count - 5; $i += 5) {
    $U = $Args[$i]; $P = $Args[$i+1]; $B = $Args[$i+2]; $F = $Args[$i+3]; $E = $Args[$i+4]

    $scriptBlock = {
        param($U,$P,$B,$F,$E,$cwd)

        # 切换到当前目录
        Set-Location $cwd

        function Download-Release {
            param($User,$Repo,$Branch,$File,$Exe)
            Write-Host "下载 $Exe ..."

            $maxRetries = 3
            $retryCount = 0
            $success = $false

            while ($retryCount -lt $maxRetries -and -not $success) {
                try {
                    Invoke-WebRequest -Uri "https://github.com/$User/$Repo/releases/download/$Branch/$File" -OutFile $File -UseBasicParsing
                    if ((Test-Path $File) -and ((Get-Item $File).Length -gt 0)) { $success = $true } else {throw "文件为空"}
                } catch {
                    $retryCount++
                    Write-Host "下载失败，重试 $retryCount/$maxRetries..."
                    Start-Sleep -Seconds 2
                }
            }

            if (-not $success) { Write-Host "下载 $File 失败，跳过 $Exe"; return }

            try {
                if ($File -match '\.zip$') {
                    Expand-Archive -Path $File -DestinationPath . -Force
                }
                Remove-Item $File
            } catch {
                Write-Host "解压 $File 失败: $_"
            }

            Write-Host "$Exe 获取成功！"
        }

        Download-Release -User $U -Repo $P -Branch $B -File $F -Exe $E
    }

    # 将 $cwd 也传入后台作业
    $jobs += Start-Job -ScriptBlock $scriptBlock -ArgumentList $U,$P,$B,$F,$E,$cwd
}

# 等待所有任务完成并获取结果
$jobs | Wait-Job
$jobs | Receive-Job
$jobs | Remove-Job
