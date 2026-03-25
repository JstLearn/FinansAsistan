# ════════════════════════════════════════════════════════════
# FinansAsistan - ArgoCD CRD Cleanup Script
# Removes finalizers from ArgoCD CRDs that are stuck in deletion
# ════════════════════════════════════════════════════════════

$ErrorActionPreference = "Continue"

function Write-Info {
    Write-Host "[INFO] $args" -ForegroundColor Blue
}

function Write-Success {
    Write-Host "[SUCCESS] $args" -ForegroundColor Green
}

function Write-Warn {
    Write-Host "[WARN] $args" -ForegroundColor Yellow
}

Write-Info "Checking for ArgoCD CRDs stuck in deletion..."

# Get all ArgoCD CRDs
$crds = kubectl get crd -o json | ConvertFrom-Json
$argocdCrds = $crds.items | Where-Object { $_.metadata.name -like "*argoproj.io" }

if ($argocdCrds) {
    Write-Info "Found $($argocdCrds.Count) ArgoCD CRDs"
    
    foreach ($crd in $argocdCrds) {
        $name = $crd.metadata.name
        
        # Check if CRD is being deleted
        if ($crd.metadata.deletionTimestamp) {
            Write-Warn "CRD '$name' is stuck in deletion (deletionTimestamp: $($crd.metadata.deletionTimestamp))"
            
            # Remove finalizers
            if ($crd.metadata.finalizers) {
                Write-Info "Removing finalizers from CRD '$name'..."
                
                # Patch CRD to remove finalizers using JSON patch
                $patchJson = '{"metadata":{"finalizers":[]}}'
                $tempFile = New-TemporaryFile
                $patchJson | Out-File -FilePath $tempFile.FullName -Encoding utf8 -NoNewline
                
                kubectl patch crd $name --type merge --patch-file $tempFile.FullName 2>&1 | Out-Null
                Remove-Item $tempFile.FullName -Force
                
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "  Finalizers removed from CRD '$name'"
                } else {
                    Write-Warn "  Failed to remove finalizers from CRD '$name', trying alternative method..."
                    # Alternative: use kubectl edit or replace
                    kubectl patch crd $name --type json -p '[{"op": "remove", "path": "/metadata/finalizers"}]' 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "  Finalizers removed using alternative method"
                    } else {
                        Write-Warn "  Could not remove finalizers. You may need to manually edit the CRD."
                    }
                }
            } else {
                Write-Info "  CRD '$name' has no finalizers, waiting for deletion to complete..."
            }
        } else {
            Write-Info "CRD '$name' is not being deleted"
        }
    }
} else {
    Write-Info "No ArgoCD CRDs found"
}

Write-Info "Waiting 5 seconds for CRDs to be fully deleted..."
Start-Sleep -Seconds 5

Write-Info "Checking remaining ArgoCD CRDs..."
$remaining = kubectl get crd 2>&1 | Select-String argoproj
if ($remaining) {
    Write-Warn "Some ArgoCD CRDs are still present:"
    $remaining | ForEach-Object { Write-Host "  $_" }
} else {
    Write-Success "All ArgoCD CRDs have been cleaned up!"
}

