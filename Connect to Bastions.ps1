# Connection Legacy Bastion Hosts

$AUS = "10.49.228.10"
$EURO = "10.49.212.10"
$SING = "10.49.214.10" #IMCP Traffic blocked
$USA = "10.49.213.10"


# Continuous Ping using Test Connection
while (1) {
   Test-Connection -ComputerName $AUS
}  


# Continous Ping
ping -t $Sing

# Australia - Detailed Ping includes Ping status
Test-NetConnection -ComputerName $AUS -InformationLevel "Detailed"

# Europe West - Detailed Ping includes Ping status
Test-NetConnection -ComputerName $EURO -InformationLevel "Detailed"

# USA - Detailed Ping includes Ping status
Test-NetConnection -ComputerName $USA -InformationLevel "Detailed"