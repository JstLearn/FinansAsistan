# FinansAsistan - AWS CLI & Terraform Setup Script
# Windows PowerShell icin otomatik kurulum

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "  FinansAsistan - AWS CLI & Terraform Setup" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# 1. PATH'e AWS CLI ve Terraform ekle
Write-Host "PATH'e AWS CLI ve Terraform ekleniyor..." -ForegroundColor Yellow

$awsPath = "C:\Program Files\Amazon\AWSCLIV2"
$terraformPath = "C:\Users\deniz\AppData\Local\Microsoft\WinGet\Packages\Hashicorp.Terraform_Microsoft.Winget.Source_8wekyb3d8bbwe"

if (Test-Path $awsPath) {
    $env:PATH += ";$awsPath"
    Write-Host "OK AWS CLI PATH'e eklendi" -ForegroundColor Green
} else {
    Write-Host "WARNING: AWS CLI bulunamadi: $awsPath" -ForegroundColor Yellow
}

if (Test-Path $terraformPath) {
    $env:PATH += ";$terraformPath"
    Write-Host "OK Terraform PATH'e eklendi" -ForegroundColor Green
} else {
    Write-Host "WARNING: Terraform bulunamadi: $terraformPath" -ForegroundColor Yellow
}

Write-Host ""

# 2. AWS CLI versiyonunu kontrol et
Write-Host "AWS CLI versiyonu kontrol ediliyor..." -ForegroundColor Yellow
try {
    $awsVersion = aws --version 2>&1
    Write-Host "OK $awsVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: AWS CLI calismiyor!" -ForegroundColor Red
    exit 1
}

# 3. Terraform versiyonunu kontrol et
Write-Host "Terraform versiyonu kontrol ediliyor..." -ForegroundColor Yellow
try {
    $terraformVersion = terraform --version 2>&1 | Select-Object -First 1
    Write-Host "OK $terraformVersion" -ForegroundColor Green
} catch {
    Write-Host "ERROR: Terraform calismiyor!" -ForegroundColor Red
    exit 1
}

Write-Host ""

# 4. AWS Credentials yapilandirmasi
Write-Host "AWS Credentials yapilandirmasi..." -ForegroundColor Yellow
Write-Host ""

$currentConfig = aws configure list 2>&1
if ($currentConfig -match "access_key.*<not set>") {
    Write-Host "AWS credentials henuz yapilandirilmamis." -ForegroundColor Yellow
    Write-Host ""
    
    $accessKey = Read-Host "AWS Access Key ID girin"
    $secretKey = Read-Host "AWS Secret Access Key girin" -AsSecureString
    $region = Read-Host "AWS Region [eu-central-1]"
    if ([string]::IsNullOrWhiteSpace($region)) {
        $region = "eu-central-1"
    }
    $outputFormat = Read-Host "Output format [json]"
    if ([string]::IsNullOrWhiteSpace($outputFormat)) {
        $outputFormat = "json"
    }
    
    # SecureString'i plain text'e cevir
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretKey)
    $plainSecretKey = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    
    # AWS CLI configure
    aws configure set aws_access_key_id $accessKey
    aws configure set aws_secret_access_key $plainSecretKey
    aws configure set default.region $region
    aws configure set default.output $outputFormat
    
    Write-Host ""
    Write-Host "OK AWS credentials yapilandirildi!" -ForegroundColor Green
} else {
    Write-Host "OK AWS credentials zaten yapilandirilmis" -ForegroundColor Green
    aws configure list
}

Write-Host ""

# 5. AWS credentials dogrulama
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

Write-Host ""

# 6. Terraform S3 State Bucket olusturma
Write-Host "Terraform State Bucket kontrol ediliyor..." -ForegroundColor Yellow

$bucketName = "finans-asistan-terraform-state"
$region = aws configure get default.region

try {
    $bucketExists = aws s3 ls "s3://$bucketName" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK Terraform state bucket zaten mevcut: $bucketName" -ForegroundColor Green
    } else {
        Write-Host "Terraform state bucket olusturuluyor..." -ForegroundColor Yellow
        
        # Bucket olustur
        aws s3 mb "s3://$bucketName" --region $region
        
        # Versioning aktif et
        aws s3api put-bucket-versioning `
            --bucket $bucketName `
            --versioning-configuration Status=Enabled `
            --region $region
        
        # Encryption aktif et
        $encryptionConfig = @{
            Rules = @(
                @{
                    ApplyServerSideEncryptionByDefault = @{
                        SSEAlgorithm = "AES256"
                    }
                }
            )
        } | ConvertTo-Json -Compress
        
        aws s3api put-bucket-encryption `
            --bucket $bucketName `
            --server-side-encryption-configuration $encryptionConfig `
            --region $region
        
        Write-Host "OK Terraform state bucket olusturuldu: $bucketName" -ForegroundColor Green
    }
} catch {
    Write-Host "WARNING: Bucket kontrolu basarisiz: $_" -ForegroundColor Yellow
}

Write-Host ""

# 7. Terraform tfvars dosyasi olusturma
Write-Host "Terraform tfvars dosyasi kontrol ediliyor..." -ForegroundColor Yellow

$tfvarsPath = "terraform\aws\terraform.tfvars"
if (Test-Path $tfvarsPath) {
    Write-Host "OK terraform.tfvars zaten mevcut" -ForegroundColor Green
    Write-Host "   Dosya: $tfvarsPath" -ForegroundColor Cyan
} else {
    Write-Host "terraform.tfvars dosyasi olusturuluyor..." -ForegroundColor Yellow
    
    $k3sToken = Read-Host "k3s Token (Initial node'dan alinacak, simdilik bos birakabilirsiniz)"
    $k3sServerUrl = Read-Host "k3s Server URL (orn: https://IP:6443, simdilik bos birakabilirsiniz)"
    
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
k3s_token = "$k3sToken"
k3s_server_url = "$k3sServerUrl"
"@
    
    # terraform/aws dizinini olustur
    $tfvarsDir = Split-Path $tfvarsPath -Parent
    if (-not (Test-Path $tfvarsDir)) {
        New-Item -ItemType Directory -Path $tfvarsDir -Force | Out-Null
    }
    
    $tfvarsContent | Out-File -FilePath $tfvarsPath -Encoding UTF8
    Write-Host "OK terraform.tfvars olusturuldu: $tfvarsPath" -ForegroundColor Green
    Write-Host "   WARNING: k3s_token ve k3s_server_url'i initial node'dan aldiktan sonra guncelleyin!" -ForegroundColor Yellow
}

Write-Host ""

# 8. Ozet
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
