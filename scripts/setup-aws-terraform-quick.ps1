# FinansAsistan - AWS CLI & Terraform Hizli Setup
# Bu script AWS credentials'i .env dosyasindan okuyup AWS CLI'yi configure eder

$env:PATH += ";C:\Program Files\Amazon\AWSCLIV2"
$terraformPath = "C:\Users\deniz\AppData\Local\Microsoft\WinGet\Packages\Hashicorp.Terraform_Microsoft.Winget.Source_8wekyb3d8bbwe"
$env:PATH += ";$terraformPath"

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "  FinansAsistan - AWS CLI & Terraform Hizli Setup" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# .env dosyasindan AWS credentials oku
$envFile = ".env"
$awsAccessKey = $null
$awsSecretKey = $null
$awsRegion = "eu-central-1"

if (Test-Path $envFile) {
    Write-Host ".env dosyasi bulundu, AWS credentials okunuyor..." -ForegroundColor Yellow
    $envContent = Get-Content $envFile -Raw
    if ($envContent -match "AWS_ACCESS_KEY_ID\s*=\s*(.+)") {
        $awsAccessKey = $matches[1].Trim()
    }
    if ($envContent -match "AWS_SECRET_ACCESS_KEY\s*=\s*(.+)") {
        $awsSecretKey = $matches[1].Trim()
    }
    if ($envContent -match "AWS_REGION\s*=\s*(.+)") {
        $awsRegion = $matches[1].Trim()
    }
    
    if ($awsAccessKey -and $awsSecretKey) {
        Write-Host "OK AWS credentials .env dosyasindan okundu" -ForegroundColor Green
        
        # AWS CLI configure
        aws configure set aws_access_key_id $awsAccessKey
        aws configure set aws_secret_access_key $awsSecretKey
        aws configure set default.region $awsRegion
        aws configure set default.output json
        
        Write-Host "OK AWS CLI configure edildi" -ForegroundColor Green
        
        # AWS credentials dogrulama
        Write-Host ""
        Write-Host "AWS credentials dogrulaniyor..." -ForegroundColor Yellow
        try {
            $identity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
            Write-Host "OK AWS credentials gecerli!" -ForegroundColor Green
            Write-Host "   Account ID: $($identity.Account)" -ForegroundColor Cyan
            Write-Host "   User ARN: $($identity.Arn)" -ForegroundColor Cyan
        } catch {
            Write-Host "ERROR: AWS credentials dogrulanamadi!" -ForegroundColor Red
            Write-Host "   Hata: $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "WARNING: .env dosyasinda AWS credentials bulunamadi" -ForegroundColor Yellow
        Write-Host "   Manuel olarak girmeniz gerekiyor:" -ForegroundColor Yellow
        Write-Host "   aws configure" -ForegroundColor White
        exit 1
    }
} else {
    Write-Host "WARNING: .env dosyasi bulunamadi" -ForegroundColor Yellow
    Write-Host "   Manuel olarak AWS credentials girmeniz gerekiyor:" -ForegroundColor Yellow
    Write-Host "   aws configure" -ForegroundColor White
    exit 1
}

Write-Host ""

# Terraform S3 State Bucket olusturma
Write-Host "Terraform State Bucket kontrol ediliyor..." -ForegroundColor Yellow

$bucketName = "finans-asistan-terraform-state"

try {
    $bucketExists = aws s3 ls "s3://$bucketName" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK Terraform state bucket zaten mevcut: $bucketName" -ForegroundColor Green
    } else {
        Write-Host "Terraform state bucket olusturuluyor..." -ForegroundColor Yellow
        
        aws s3 mb "s3://$bucketName" --region $awsRegion
        
        aws s3api put-bucket-versioning `
            --bucket $bucketName `
            --versioning-configuration Status=Enabled `
            --region $awsRegion
        
        $encryptionConfig = '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
        aws s3api put-bucket-encryption `
            --bucket $bucketName `
            --server-side-encryption-configuration $encryptionConfig `
            --region $awsRegion
        
        Write-Host "OK Terraform state bucket olusturuldu: $bucketName" -ForegroundColor Green
    }
} catch {
    Write-Host "WARNING: Bucket kontrolu basarisiz: $_" -ForegroundColor Yellow
}

Write-Host ""

# Terraform tfvars dosyasi olusturma
Write-Host "Terraform tfvars dosyasi kontrol ediliyor..." -ForegroundColor Yellow

$tfvarsPath = "terraform\aws\terraform.tfvars"
if (Test-Path $tfvarsPath) {
    Write-Host "OK terraform.tfvars zaten mevcut" -ForegroundColor Green
    Write-Host "   Dosya: $tfvarsPath" -ForegroundColor Cyan
} else {
    Write-Host "terraform.tfvars dosyasi olusturuluyor..." -ForegroundColor Yellow
    
    $tfvarsContent = @"
# AWS Configuration
aws_region = "eu-central-1"
environment = "production"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

# EC2 Instance Configuration
worker_instance_type = "t3.xlarge"  # 4 vCPU, 16GB RAM
worker_min_size = 0                 # Baslangicta 0 node
worker_max_size = 50                # Maksimum 50 node
worker_desired_capacity = 0         # Baslangicta 0 node

# k3s Configuration (Initial node'dan alinacak)
# NOT: Bu degerleri initial node'dan aldiktan sonra guncelleyin!
k3s_token = ""
k3s_server_url = ""
"@
    
    $tfvarsDir = Split-Path $tfvarsPath -Parent
    if (-not (Test-Path $tfvarsDir)) {
        New-Item -ItemType Directory -Path $tfvarsDir -Force | Out-Null
    }
    
    $tfvarsContent | Out-File -FilePath $tfvarsPath -Encoding UTF8
    Write-Host "OK terraform.tfvars olusturuldu: $tfvarsPath" -ForegroundColor Green
    Write-Host "   WARNING: k3s_token ve k3s_server_url'i initial node'dan aldiktan sonra guncelleyin!" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "OK Kurulum tamamlandi!" -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Sonraki adimlar:" -ForegroundColor Yellow
Write-Host "   1. Initial node'da k3s kurulu olmali" -ForegroundColor White
Write-Host "   2. k3s token'i al: cat /var/lib/rancher/k3s/server/node-token" -ForegroundColor White
Write-Host "   3. terraform/aws/terraform.tfvars dosyasini guncelle" -ForegroundColor White
Write-Host "   4. Terraform'u calistir:" -ForegroundColor White
Write-Host "      cd terraform/aws" -ForegroundColor Cyan
Write-Host "      terraform init" -ForegroundColor Cyan
Write-Host "      terraform plan" -ForegroundColor Cyan
Write-Host "      terraform apply" -ForegroundColor Cyan
Write-Host ""

