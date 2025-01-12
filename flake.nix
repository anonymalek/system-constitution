{
	inputs = {
		nixpkgs.url = "nixpkgs/nixos-unstable";
		nixpkgs-stable.url = "nixpkgs/nixos-24.05";
		nixpkgs-unstable.url = "nixpkgs/nixos-unstable";

		home-manager = {
			url = "github:nix-community/home-manager";
			inputs.nixpkgs.follows = "nixpkgs";
		};
		
		nur.url = "github:nix-community/NUR";
	};

	outputs = inputArgs@{ nixpkgs, nixpkgs-stable, nixpkgs-unstable, home-manager, nur, ... }:
		let
			args = inputArgs // {
				system = "x86_64-linux";

				systemPath = ./system;
				userPath = ./user;

				lawConfig = import ./config.nix;

				nur-modules = import nur {
					nurpkgs = nixpkgs.legacyPackages.x86_64-linux;
				};
			};

			nixosCustomSystem = { modules }: nixpkgs.lib.nixosSystem {
				system = args.system;
				specialArgs = args;

				modules = [
					./system/global.nix
					nur.nixosModules.nur

					home-manager.nixosModules.home-manager

					({ config, lib, pkgs, ... }: {imports = [
						((import ./system/law.nix (args // {
							inherit config lib pkgs;
							pkgs-stable = config.pkgs-stable;
							pkgs-unstable = config.pkgs-unstable;
						})).makeSystemModulesByPath modules)
					];})
				];
			};

			lib = nixpkgs.lib;
			utils = import ./system/utils.nix { inherit lib; };

			extractConfigurationsFromUserDirectory = user:
			let
				dir = ./. + "/user/${user}";
				hwdir = ./. + "/user/${user}/hardware";
			in lib.attrsets.mergeAttrsList (if (utils.hasDirectory dir "hardware") then
				(lib.lists.forEach (utils.getDirectories hwdir)
					(hw: { "${user}.${hw}" = lib.concatLists [
						[ (./. + "/user/${user}/hardware/${hw}/system.nix") ]
						(if (utils.hasFile dir "system.nix")
						then [ (./. + "/user/${user}/system.nix") ]
						else [])
					]; })
				)
			else []);

			lawMachines = (lib.attrsets.mergeAttrsList
				(lib.lists.forEach (utils.getDirectories ./user)
					(user: extractConfigurationsFromUserDirectory user)));
		in {
		nixosConfigurations = lib.attrsets.mapAttrs
			(name: moduleList: nixosCustomSystem {
				modules = moduleList;
			}) lawMachines;
	};
}
