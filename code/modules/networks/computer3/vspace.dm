
/datum/virtualworld
	var/name = ""
	var/datum/allocated_region/region = null
	var/spawnloc = null;

	New(var/Width, var/Height)
		..()
		var/name_num = 0
		while(landmarks["uservr_[name_num]"])
			name_num++
		name = "uservr_[name_num]"
		region = region_allocator.allocate(Width, Height, name)

		spawnloc = region.get_center();
		if(!landmarks[name])
			landmarks[name] = list()
		landmarks[name][spawnloc] = null

		region.clean_up(/turf/simulated/floor, /turf/cordon, /area/sim)


/datum/computer/file/vspace
	name = "Virtual World"
	extension = "VSP" //Virtual space :D
	size = 1 //Size is set in New(), this is not accurate
	dont_copy = 1 //NO, I don't even want to think about cloning region allocations...
	var/datum/virtualworld/vspace = null;

	New(var/Width, var/Height)
		..()
		//Ensures we're working with odd numbers
		if(!(Width & 1))Width--
		if(!(Height & 1))Height--

		//Anything less than 3 is ridiculous
		if(Width < 3)Width = 3
		if(Height< 3)Height = 3

		vspace = new /datum/virtualworld(Width,Height)

		size = (Width+1 >> 1) * (Height+1 >> 1) //Half width multiplied by half height so you can have bigger VR spaces on disk.


/datum/computer/file/terminal_program/vspaceman
	name = "VSpaceMan"
	var/datum/computer/file/vspace/loaded_simulation = null

	initialize()
		if (..())
			return TRUE
		//Todo: check if we have a radio card and tell user if we don't
		src.print_text("Virtual Space Manager 0.1<br>Commands:<br>create width height fileame: Creates a new virtual world.<br>host filename: Simulates a virtual world.")

	disposing()
		loaded_simulation = null
		..()

	input_text(text)
		if(..())
			return

		var/list/command_list = parse_string(text)
		var/command = command_list[1]
		command_list -= command_list[1]

		src.print_text(strip_html(text))

		if(loaded_simulation)
			simulation_input(command,command_list)
			return

		switch(lowertext(command))
			if("create")
				if(command_list.len < 3)
					src.print_text("Error: Incorrect number of arguments. Expected: Width, Height, Filename")
					return
				var/arg_w = command_list[1]
				var/arg_h = command_list[2]
				var/arg_fn = command_list[3]

				var/checkfile = find_file_in_folder(src.holding_folder,arg_fn)
				if(checkfile)
					src.print_text("Error: File with name '[arg_fn]' already exists, please choose another name.")
					return

				if(text2num(arg_w) < 3)
					src.print_text("Error: Width must be larger than 3.")
					return
				if(text2num(arg_h) < 3)
					src.print_text("Error: Height must be larger than 3.")
					return

				var/datum/computer/file/vspace/newfile = new /datum/computer/file/vspace(text2num(arg_w),text2num(arg_h))
				newfile.name = arg_fn
				if(!src.holding_folder.add_file(newfile))
					src.print_text("Error: Not enough drive space.")
					newfile.dispose()
					return
				src.print_text("Success: Created a world of size [arg_w]x[arg_h]!<br>Use 'host [arg_fn]' to run it.")

			if("host")
				if(command_list.len < 1)
					src.print_text("Error: Incorrect number of arguments. Expected: Filename")
					return
				var/arg_fn = command_list[1]
				var/datum/computer/file/vspace/checkfile = find_file_in_folder(src.holding_folder,arg_fn)
				if(!checkfile)
					src.print_text("Error: No file under the name '[arg_fn]'.")
					return
				if(!istype(checkfile))
					src.print_text("Error: '[arg_fn]' is the incorrect file type, expected VSP.")
					return
				loaded_simulation = checkfile
				src.print_text("Hosting simulation '[arg_fn]'...")

			else
				src.print_text("Error: Unknown Command.")

		src.master.add_fingerprint(usr)
		src.master.updateUsrDialog()
		return

	proc/simulation_input(var/command, var/list/command_list)
		switch(lowertext(command))
			if("quit")
				src.print_text("Ending simulation...")
				loaded_simulation = null
				return
			else
				src.print_text("Error: Unknown Command.")
				return

	proc/find_file_in_folder(datum/computer/folder/search_folder, var/name)
		for(var/datum/computer/P in search_folder.contents)
			if(P.name == name)
				return P
		return null

	receive_command(obj/source, command, datum/signal/signal)
		if((..()) || (!signal))
			return

		message_coders("Gothere7")

		if(!src.loaded_simulation || !src.loaded_simulation.vspace) //We better actually be running the simulation you know
			return

		message_coders("Gothere7.1 command:"+command)
		signal.show()

		var/target = signal.data["sender"]
		if(signal.data["cmd"] == "jackin")
			message_coders("Gothere8")
			if(!signal.data["netid"] && !signal.data["address_1"])
				return
			message_coders("Gothere9")
			var/datum/signal/newsignal = get_free_signal()
			newsignal.source = src
			newsignal.transmission_method = TRANSMISSION_RADIO
			newsignal.data["command"] = "jackin"
			newsignal.data["address_1"] = target
			newsignal.data["network"] = src.loaded_simulation.vspace.name //One hell of an access chain

			var/obj/item/peripheral/network/net_card = find_peripheral("RAD_ADAPTER")
			if (net_card && istype(net_card))
				message_coders("Gothere11")
				SPAWN(0.5 SECONDS)
					src.peripheral_command("transmit", newsignal, "\ref[net_card]")

		return


///Debug computer
/obj/machinery/computer3/generic/vspace
	setup_starting_program = /datum/computer/file/terminal_program/vspaceman
	setup_starting_peripheral1 = /obj/item/peripheral/network/radio

#define FREQ_VR 1419//1235
///Funky packet headset
/obj/item/clothing/glasses/compvr
	name = "\improper VR goggles"
	desc = "A pair of VR goggles running a personal simulation."
	icon_state = "vr"
	item_state = "vr"
	var/network = ""
	var/test = null
	var/joincode = "ping"
	var/net_id = null;

	setupProperties()
		..()
		setProperty("disorient_resist_eye", 28)

	New()
		SPAWN(2 SECONDS)
			if (src)
				src.name += " - '[src.network]'" // They otherwise all look the same (Convair880).
		..()
		src.net_id = generate_net_id(src)
		src.AddComponent( \
			/datum/component/packet_connected/radio, \
			"vr_goggles", \
			FREQ_VR, \
			src.net_id, \
			"receive_signal", \
			FALSE, \
			"NET_VR", \
			FALSE \
		)

	equipped(var/mob/user, var/slot)
		..()
		message_coders("Gothere1")
		var/datum/signal/newsignal = get_free_signal()
		newsignal.source = src
		newsignal.transmission_method = TRANSMISSION_RADIO
		newsignal.data["address_1"] = "ping"
		newsignal.data["cmd"] = "jackin"
		newsignal.data["sender"] = src.net_id
		SEND_SIGNAL(src, COMSIG_MOVABLE_POST_RADIO_PACKET, newsignal, null, "vr_goggles")
		return

	unequipped(var/mob/user)
		..()
		if(ishuman(user) && user:network_device == src)
			user:network_device = null
		return

	attack_self(mob/user)
		src.joincode = tgui_input_text(user, "Enter an address to connect to:","Host connection", src.joincode, 8)

	receive_signal(datum/signal/signal)
		if(!signal)
			return

		var/target = signal.data["sender"]
		var/command = signal.data["command"]

		if((signal.data["address_1"] == "ping") && target)
			SPAWN(0.5 SECONDS)
				var/datum/signal/newsignal = get_free_signal()
				newsignal.source = src
				newsignal.transmission_method = TRANSMISSION_RADIO
				newsignal.data["command"] = "ping_reply"
				newsignal.data["device"] = "NET_VR"
				newsignal.data["netid"] = src.net_id
				newsignal.data["address_1"] = target
				newsignal.data["sender"] = src.net_id
				SEND_SIGNAL(src, COMSIG_MOVABLE_POST_RADIO_PACKET, newsignal, null, "vr_goggles")

			return

		if (signal.data["address_tag"] == "NET_VR" || signal.data["address_1"] == src.net_id)
			message_coders("Gothere2")
			if(command == "ping_reply")
				//So you might be wondering, how do we know this wireless pc is hosting a virtual world?
				//The answer: we don't
				// Because PROGRAMS CAN'T OVERRIDE HOW THE WIRELESS PERIPHERAL RESPONDS TO PINGS
				// So yes we just send a join request to every wireless computer that responds to the ping and hope it works
				message_coders("Gothere3 target:"+target)
				var/datum/signal/newsignal = get_free_signal()
				newsignal.source = src
				newsignal.transmission_method = TRANSMISSION_RADIO
				newsignal.data["command"] = "jackin"
				newsignal.data["cmd"] = "jackin" //Command gets overriden for some reason??
				newsignal.data["address_1"] = target
				newsignal.data["sender"] = src.net_id
				SPAWN(0.5 SECONDS)
					SEND_SIGNAL(src, COMSIG_MOVABLE_POST_RADIO_PACKET, newsignal, null, "vr_goggles")

				return

			if(command == "jackin")
				message_coders("Gothere4")
				var/networkname = signal.data["network"];
				if(!networkname)
					return
				message_coders("Gothere5")
				var/mob/living/carbon/human/H = src.loc //Probably works?
				if(istype(H) && equipped_in_slot == SLOT_GLASSES && !H.network_device && !inafterlife(H))
					H.network_device = src
					Station_VNet.Enter_Vspace(H, src,networkname)
					message_coders("Gothere6")
				return
		else
			return
