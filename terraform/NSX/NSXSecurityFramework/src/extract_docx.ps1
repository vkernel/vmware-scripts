$wordApp = New-Object -ComObject Word.Application
$wordApp.Visible = $false
$doc = $wordApp.Documents.Open("$PSScriptRoot\NSX_Security_Framework.docx")

# Create markdown file
$output = "# NSX Security Framework`n`n"

# Get all text
$output += $doc.Content.Text

# Save the markdown file
$output | Out-File -FilePath "$PSScriptRoot\NSX_Security_Framework.md" -Encoding utf8

# Close document and quit Word
$doc.Close()
$wordApp.Quit()

# Release COM objects
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($doc) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($wordApp) | Out-Null
[System.GC]::Collect()
[System.GC]::WaitForPendingFinalizers()

Write-Host "Extraction complete. File saved as NSX_Security_Framework.md" 