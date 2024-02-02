virtdeclareFile:
let
    module = isHomeManager: {config, lib, ...}:
    let
        cfg = config.virtualisation.libvirt;
    in
    {
        options.virtualisation.libvirt = with lib.types;
        {
            enable = lib.mkOption
            {
                type = bool;
                default = false;
                description = "Enable management of libvirt domains";
            };
            domains = lib.mkOption
            {
                type = listOf (submodule
                {
                    options =
                    {
                        connection = lib.mkOption
                        {
                            type = str;
                            default = if isHomeManager then "qemu:///session" else "qemu:///system";
                            description = "hypervisor connection URI";
                        };
                        definition = lib.mkOption
                        {
                            type = path;
                            description = "path to definition XML";
                        };
                        active = lib.mkOption
                        {
                            type = types.nullOr types.bool;
                            default = null;
                            description = "running/stopped state to put the domain in (or null for ignore)";
                        };
                    };
                });
                default = [];
                description = "libvirt domains";
            };
        };

        config = lib.mkIf cfg.enable
        (let
            mkCommands = objtype: {connection,definition,active}:
            let
                stateOption = if builtins.isNull active
                    then ""
                    else if active then "--state active" else "--state inactive";
            in
            ''
                ${virtdeclareFile} --connect ${connection} --type ${objtype} --define ${definition} ${stateOption}
            '';
            script = lib.concatStrings (lib.lists.forEach cfg.domains (mkCommands "domain"));
        in
        if isHomeManager
        then
        {
            home.activation.libvirt-domains = script;
        }
        else
        {
            virtualisation.libvirtd.enable = true;
            systemd.services.nixvirt =
            {
                serviceConfig.Type = "oneshot";
                description = "Configure libvirt domains";
                wantedBy = ["multi-user.target"];
                requires = ["libvirtd.service"];
                after = ["libvirtd.service"];
                inherit script;
            };
        }
        );
    };
in
{
    nixosModule = module false;
    homeModule = module true;
}
