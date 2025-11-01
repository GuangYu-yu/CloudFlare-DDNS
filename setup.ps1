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

    $maxRetries = 3
    $retryCount = 0
    $success = $false

    while ($retryCount -lt $maxRetries -and -not $success) {
        try {
            Invoke-WebRequest -Uri "https://github.com/$User/$Repo/releases/download/$Branch/$File" -OutFile $File -UseBasicParsing
            if ((Test-Path $File) -and ((Get-Item $File).Length -gt 0)) {
                $success = $true
            } else {
                throw "文件为空"
            }
        } catch {
            $retryCount++
            Write-Host "下载失败，重试 $retryCount/$maxRetries..."
            Start-Sleep -Seconds 2
        }
    }

    if (-not $success) {
        Write-Host "下载 $File 失败，跳过 $Exe"
        return
    }

    # 解压 tar.gz
    try {
        # PowerShell 7+ 支持直接解压 tar.gz
        tar -xzf $File
        Remove-Item $File
    } catch {
        Write-Host "解压 $File 失败: $_"
    }

    # 设置可执行权限（Windows 下可以略过或设置执行策略）
    Write-Host "$Exe 获取成功！"
}

# 每 5 个参数一组
$jobs = @()
for ($i = 0; $i -le $Args.Count - 5; $i += 5) {
    $U = $Args[$i]
    $P = $Args[$i+1]
    $B = $Args[$i+2]
    $F = $Args[$i+3]
    $E = $Args[$i+4]

    # 启动后台任务
    $jobs += Start-Job -ScriptBlock { param($U,$P,$B,$F,$E) Download-Release -User $U -Repo $P -Branch $B -File $F -Exe $E } -ArgumentList $U,$P,$B,$F,$E
}

# 等待所有任务完成
$jobs | Wait-Job
$jobs | Receive-Job
$jobs | Remove-Job
