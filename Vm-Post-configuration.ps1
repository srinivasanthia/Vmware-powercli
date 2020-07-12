# Script By Srinivasan Thiagarajan 
# srinivasan.thia@gmail.com
# Skype : srinivasan.thia

$ErrorActionPreference = "Stop"
$Warningpreference = "SilentlyContinue"
Add-PSSnapin VMware.VIMAutomation.core
Connect-viserver -server "10.127.123.26"
$inputfile = ".\test.csv"


$records =import-csv $inputfile 



do 
{
clear-host

write-host "*************************************************************************************" -foregroundcolor yellow
Write-host "-------IBM Workload Migration services - Windows post configuration script ----------" -foregroundcolor yellow
Write-host "*************************************************************************************" -foregroundcolor yellow

Write-Host "Note: Please make sure the VM is powered ON " -foregroundcolor yellow
write-host ""

$servername = Read-host -prompt 'Enter the server name:-'
write-host ""
Write-host "*************************************************************************************" -foregroundcolor yellow



If ($servername)

{

$Filteredrecords = $records | ? { $_.name -match "$servername"}


   $vmname = $Filteredrecords.name
   $pportgroup = $Filteredrecords.Prodportgroup
   $mportgroup = $Filteredrecords.Managementportgroup
   $bportgroup = $Filteredrecords.Backupportgroup
   $prodip = $Filteredrecords.prodip
   $Mask = $Filteredrecords.mask
   $prodgtw = $Filteredrecords.prodgtw
   $mgmtip = $Filteredrecords.mgmtip
   $backupip = $Filteredrecords.backupip
   $dns1 = $Filteredrecords.dns1
   $dns2 = $Filteredrecords.dns2
   $vmusername = $Filteredrecords.vmusername
   $vmpassword = $Filteredrecords.vmpassword
   $vmsite = $Filteredrecords.location
   $NTP1 = $Filteredrecords.NTP1
   $NTP2 = $Filteredrecords.NTP2
   $NTP3 = $Filteredrecords.NTP3
   $backupNw1 = "10.111.122.0"   
   $backupNw2 = "10.127.122.0"
   $mgmtnw1 = "10.111.123.0"
   $mgmtnw2 = "10.127.123.0"
If ( $servername -eq $vmname )
{ 

write-host "Processing"
write-host ""}

Else {
Write-host "Servername not found "
exit
}

Write-host -nonewline "Please Confirm the servername : $vmname "
$confirm = Read-host -prompt "Yes or No "
write-host ""
Write-host "*************************************************************************************" -foregroundcolor yellow

$No = "No"
$N = "N"
$yes ="Yes"
$y = "y"

If ( $confirm -eq $yes -or $confirm -eq $y )
{
Write-host " Post config is running for the server $vmname "
Write-host "*************************************************************************************" -foregroundcolor yellow

}
Else
{
exit
}

try
{


$power = get-vm $vmname 

if($power.powerstate -eq "poweredon")
{
Write-host " VM is Powered on and running"
}

Else
{
Write-host "Virtual machine is powered off, Please power on to execute the script"
Exit
}

if ( !$power.toolsversionstatus )
{

Write-Host " VMware Tools not installed on the machine please install the tools and run the script again"
exit
}

update-Tools $Vmname -NoReboot

$status = $?

If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "1.VMware Tools update status---------------------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "1.VMware Tools update status---------------------------------------------->"
Write-host "Failed" -foregroundcolor Red }


$prodcard = get-NetworkAdapter -VM $vmname | where { $_.NetworkName -eq $pportgroup }
$prodmac = $prodcard.macaddress



$Mgmtcard = get-NetworkAdapter -VM $vmname | where { $_.NetworkName -eq $mportgroup }
$Mgmtmac = $Mgmtcard.macaddress



$Backupcard = get-NetworkAdapter -VM $vmname | where { $_.NetworkName -eq $bportgroup }
$Backupmac = $Backupcard.macaddress



$pscript = @"
`$wmi = Get-wmiobject -Class win32_Networkadapter -Filter "MACaddress = '$prodmac'"
`$wmi.NetconnectionID = 'Prod'
`$wmi.put()


"@
 
Invoke-Vmscript -VM $vmname -ScriptText $pscript -Guestuser $vmusername -GuestPassword $vmpassword | out-null

$status = $?

If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "2.Production Network Adapter Rename Status-------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "2.Production Network Adapter Rename Status-------------------------------->"
Write-host "Failed" -foregroundcolor Red }

$mscript = @"
`$wmi = Get-wmiobject -Class win32_Networkadapter -Filter "MACaddress = '$Mgmtmac'"
`$wmi.NetconnectionID = 'Mgmt'
`$wmi.put()

"@
 
Invoke-Vmscript -VM $vmname -ScriptText $mscript -Guestuser $vmusername -GuestPassword $vmpassword | out-null

$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "3.Management Network Adapter Rename Status-------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "3.Management Network Adapter Rename Status-------------------------------->"
Write-host "Failed" -foregroundcolor Red }

$bscript = @"
`$wmi = Get-wmiobject -Class win32_Networkadapter -Filter "MACaddress = '$Backupmac'"
`$wmi.NetconnectionID = 'Backup'
`$wmi.put()

"@
 
Invoke-Vmscript -VM $vmname -ScriptText $bscript -Guestuser $vmusername -GuestPassword $vmpassword | out-null

$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "4.Backup Network Adapter Rename Status------------------------------------>"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "4.Backup Network Adapter Rename Status------------------------------------>"
Write-host "Failed" -foregroundcolor Red }



Invoke-VMScript -VM $vmname -scriptText "route -f" -guestUser $vmusername -guestPassword $vmpassword -scriptType bat| out-null

$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "5.Clear All Persistent routes--------------------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "5.Clear All Persistent routes--------------------------------------------->"
Write-host "Failed" -foregroundcolor Red }




$pipconfig = 'netsh interface ipv4 set address name= Prod source=static address=' +$prodip+ ' mask=' +$Mask+ ' gateway=' +$prodgtw+ ' gwmetric=1 store=persistent'

Invoke-VMScript -VM $vmname -scriptText $pipconfig -guestUser $vmusername -guestPassword $vmpassword -scriptType Bat | out-null

$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "6.Production Nework Adapter IP Config------------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "6.Production Nework Adapter IP Config------------------------------------->"
Write-host "Failed" -foregroundcolor Red }



$mipconfig = 'netsh interface ipv4 set address name= Mgmt source=static address=' +$mgmtip+ ' mask=' +$Mask+ ' store=persistent'

Invoke-VMScript -VM $vmname -scriptText $mipconfig -guestUser $vmusername -guestPassword $vmpassword -scriptType Bat | out-null

$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "7.Management Nework Adapter IP Config------------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "7.Management Nework Adapter IP Config------------------------------------->"
Write-host "Failed" -foregroundcolor Red }

$bipconfig = 'netsh interface ipv4 set address name= Backup source=static address=' +$backupip+ ' mask=' +$Mask+ ' store=persistent'

Invoke-VMScript -VM $vmname -scriptText $bipconfig -guestUser $vmusername -guestPassword $vmpassword -scriptType Bat | out-null


$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "8.Backup Nework Adapter IP Config----------------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "8.Backup Nework Adapter IP Config----------------------------------------->"
Write-host "Failed" -foregroundcolor Red }



$pdnsconfig = 'netsh interface ipv4 set dns name="Prod" static address=' +$dns1+ ' primary'

$sdnsconfig = 'netsh interface ipv4 add dnsservers name="Prod" address=' +$dns2+ ' index=2'

Invoke-VMScript -VM $vmname -ScriptText $pdnsconfig -guestUser $vmusername -guestPassword $vmpassword -scriptType Bat | out-null

$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "9.Prod Network Adapter Primary DNS Config--------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "9.Prod Network Adapter Primary DNS Config--------------------------------->"
Write-host "Failed" -foregroundcolor Red }



Invoke-VMScript -VM $vmname -ScriptText $sdnsconfig -guestUser $vmusername -guestPassword $vmpassword -scriptType Bat | out-null

$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "10.Prod Network Adapter Secondary DNS Config------------------------------>"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "10.Prod Network Adapter Secondary DNS Config------------------------------>"
Write-host "Failed" -foregroundcolor Red }


$a,$b,$c,$d = $mgmtip.split('.')


$d=1

$mgmtgtw = $a,$b,$c,$d -join "."

$mroute1 = 'route -p add ' +$mgmtnw1+ ' MASK ' +$mask + ' ' +$mgmtgtw+ ''

$mroute2 = 'route -p add ' +$mgmtnw2+ ' MASK ' +$mask + ' ' +$mgmtgtw+ ''

Invoke-VMScript -VM $vmname -scriptText $mroute1 -guestUser $vmusername -guestPassword $vmpassword -scriptType bat | out-null

Invoke-VMScript -VM $vmname -scriptText $mroute2 -guestUser $vmusername -guestPassword $vmpassword -scriptType bat | out-null



$a,$b,$c,$d = $backupip.split('.')
$d=1
$backupgtw =  $a,$b,$c,$d -join "."

$broute1 = 'route -p add ' +$backupNw1+ ' MASK ' +$mask + ' ' +$backupgtw+ ''

$broute2 = 'route -p add ' +$backupNw2+ ' MASK ' +$mask + ' ' +$backupgtw+ ''

Invoke-VMScript -VM $vmname -scriptText $broute1 -guestUser $vmusername -guestPassword $vmpassword -scriptType bat | out-null

Invoke-VMScript -VM $vmname -scriptText $broute2 -guestUser $vmusername -guestPassword $vmpassword -scriptType bat | out-null






$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "11.Persistent Route Configuration----------------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "11.Persistent Route Configuration----------------------------------------->"
Write-host "Failed" -foregroundcolor Red }





Invoke-VMScript -VM $vmname -scriptText "ipconfig /flushdns" -guestUser $vmusername -guestPassword $vmpassword -scriptType bat | out-null

$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "12.Cleared DNS Cache------------------------------------------------------>"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "12.Cleared DNS Cache------------------------------------------------------>"
Write-host "Failed" -foregroundcolor Red }

Invoke-VMScript -VM $vmname -scriptText "ipconfig /registerdns" -guestUser $vmusername -guestPassword $vmpassword -scriptType bat | out-null

$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "13.Initiated DNS Client registration-------------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "13.Initiated DNS Client registration-------------------------------------->"
Write-host "Failed" -foregroundcolor Red }


Invoke-VMScript -VM $vmname -scriptText "net start w32time" -guestUser $vmusername -guestPassword $vmpassword -scriptType bat | out-null


$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "14.NTP Service Started---------------------------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "14.NTP Service Started---------------------------------------------------->"
Write-host "Failed" -foregroundcolor Red }

Invoke-VMScript -VM $vmname -scriptText "w32tm /resync" -guestUser $vmusername -guestPassword $vmpassword -scriptType bat| out-null

$NTPScript = 'w32tm /config /syncfromflags:manual /manualpeerlist:"$NTP1 $NTP2 $NTP3" /update /reliable:yes'

Invoke-VMScript -VM $vmname -scriptText $NTPScript -guestUser $vmusername -guestPassword $vmpassword -scriptType bat | out-null

$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "15.NTP IP configuration--------------------------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "15.NTP IP configuration--------------------------------------------------->"
Write-host "Failed" -foregroundcolor Red }


Invoke-VMScript -VM $vmname -scriptText "w32tm /query /status" -guestUser $vmusername -guestPassword $vmpassword -scriptType bat | out-null 

$ipv6 = "reg add hklm\system\currentcontrolset\services\tcpip6\parameters /v DisabledComponents /t REG_DWORD /d 255 /f"

Invoke-VMScript -VM $vmname -scriptText $ipv6 -guestUser $vmusername -guestPassword $vmpassword -scriptType bat | out-null 

$status = $?
If ( $status -like $True ) {
Write-host ""
Write-host -nonewline "16.Disable IPv6 ---------------------------------------------------------->"
Write-host "Completed" -foregroundcolor Green }
else {
Write-host ""
Write-host -nonewline "16.Disable IPv6 ---------------------------------------------------------->"
Write-host "Failed" -foregroundcolor Red }
Write-host "Please restart the machine" -foregroundcolor yellow
write-host ""

Invoke-VMScript -VM $vmname -scriptText " netsh interface ipv4 set dnsservers name= Backup source=DHCP register=none" -guestUser $vmusername -guestPassword $vmpassword -scriptType bat | out-null 
Invoke-VMScript -VM $vmname -scriptText " netsh interface ipv4 set dnsservers name= Mgmt source=DHCP register=none" -guestUser $vmusername -guestPassword $vmpassword -scriptType bat | out-null 






Write-host "********************************************************************************" -foregroundcolor yellow
write-host ""
write-host "Need to execute the script for another server :" 
$proceed = Read-Host -prompt " Yes or No"



}
catch
{



Write-host "Error in Execution "

$ErrorMessage = $_.Exception.Message
$ErrorSource = $_.Exception

write-host $ErrorMessage -ForegroundColor Red
write-host $ErrorSource -ForegroundColor Red
#Write-Host $FailedItem


}

}
Else { Write-host "Servername is Empty" }

}

while ( $proceed -eq "yes" -or $proceed -eq "y" )

If ( $proceed -eq "yes" -or $proceed -eq "y")
{
Sleep -Seconds 10
}
Else 
{
read-host -prompt "Enter to exit"
}


