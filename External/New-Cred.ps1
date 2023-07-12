function New-Cred ($User, $Password)
{
    $secpasswd = ConvertTo-SecureString "$Password" -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($User, $secpasswd)    
}

