#Requires -Version 4.0
#Requires -RunAsAdministrator
Configuration VAgentDSC {
    param
    (
        [string[]]$NodeName = 'localhost'
    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Node $NodeName
    {

        Service VAgentService
        {
            Name        = "Vagent"            
            State       = "Running"
        } 
    }

}

if (-not(test-path -Path C:\DSC\Vagent -PathType Container)){
    mkdir C:\DSC\Vagent
}
# Compile the configuration file to a MOF format
 VAgentDSC -OutputPath C:\DSC\Vagent

# Run the configuration on localhost
Start-DscConfiguration -Path C:\DSC\Vagent -ComputerName localhost -Force -Wait