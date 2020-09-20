//This file contains code for the ingame loadout selector, used by players AFTER they have already spawned into the round
//How to use? Simply add a /datum/outfit/loadout to the loadout_options list on each job, in the job_types folder

/mob/proc/select_loadout()
	set name = "Select Loadout"
	set category = "IC"


	//To select loadout, the mob must have a loadout selector component
	var/datum/component/loadout_selector/LS = GetComponent(/datum/component/loadout_selector)
	if (!istype(LS))
		//Error message, shouldn't be seen but just incase
		to_chat(src, SPAN_DANGER("You have either already selected a loadout, or have no options."))

		//If they don't have it, they shouldn't have this verb either
		disable_loadout_select(src)
		return

	LS.ui_interact(src)



//Called when someone spawns in, or maybe if an admin does a thing
/proc/enable_loadout_select(var/mob/M)
	//Delay the notification message for a few seconds so players are less likely to miss it
	spawn(50)
		to_chat(M, SPAN_NOTICE("-------------------------------------------"))
		to_chat(M, SPAN_NOTICE("Your job has additional loadout options you can choose from. Use the Loadout Selector in your hands, or the Select Loadout verb in the IC menu to choose your additional equipment."))
		to_chat(M, SPAN_NOTICE("-------------------------------------------"))
	M.verbs += /mob/proc/select_loadout
	var/datum/component/loadout_selector/LS = M.AddComponent(/datum/component/loadout_selector) //Create the loadout selecting component
	var/token = new /obj/item/loadout_token
	LS.token = token
	M.put_in_hands(token)

//Cleans up the verbs, objects and components
//Called after a loadout is selected, or if the user tries to do some exploit to pick a second loadout
/proc/disable_loadout_select(var/mob/M)
	var/datum/component/loadout_selector/LS = M.GetComponent(/datum/component/loadout_selector)
	if (LS)
		//Lets close the open UI
		var/datum/tgui/ui = SStgui.try_update_ui(M, LS, "loadout_select", null, 0)
		if (ui)
			ui.close()

		M.deleteWornItem(LS.token)

	M.verbs -= /mob/proc/select_loadout //Remove the verb
	M.RemoveComponentByType(/datum/component/loadout_selector) //Remove component

/****************
	Object
****************/
/obj/item/loadout_token
	name = "Select Loadout"
	desc = "Activate this item to select your additional loadout equipment. It will vanish once you're done."
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "loadout"
	item_flags = NODROP

/obj/item/loadout_token/attack_self(var/mob/user)
	user.select_loadout()

/****************
	Component
****************/
//A datum that handles the menu for loadout selecting, to save on adding variables to things
/datum/component/loadout_selector
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/list/loadout_options = list() //List of names and typepaths
	var/selected_name = "" //Name of the outfit currently selected
	var/datum/outfit/selected_datum = null //Reference to the datum of the outfit currently selected
	var/selected_items = list() //List of atoms in the selected outfit, this is a list of sublists in the format:
		//name, icon, quantity

	//A list of names in a format that tgui likes, autogenerated
	var/list/data_names = list()

	//To save on constantly doing expensive operations, we will generate preview images once for each mannequin and cache them
	var/list/preview_images = list()

	var/selected_direction = SOUTH

	var/obj/item/loadout_token/token = null

//Lets check that the assigned parent is a mob with a job
/datum/component/loadout_selector/Initialize()
	var/mob/living/L = parent
	if (istype(L))
		var/datum/job/J = L.GetJob()
		if (J)
			for (var/a in J.loadout_options) //Copy the options from the job
				var/datum/outfit/o = a
				loadout_options[initial(o.name)] = a
				data_names.Add(list(list("name" = initial(o.name))))
			return ..()

	//If they don't have a job they cant use this
	return COMPONENT_INCOMPATIBLE

//This completes loadout selection, spawns the selected outfit and cleans things up
/datum/component/loadout_selector/proc/finish()
	//First of all, safety checks
	if (!selected_datum)
		return
	if (!parent)
		return

	var/mob/M = parent
	var/obj/item/storage/box/large/kitbox = new
	kitbox.name = "Outfit: [selected_datum.name]"
	kitbox.desc = "A box, supplying what you need."
	kitbox.w_class = WEIGHT_CLASS_BULKY
	selected_datum.spawn_at(kitbox)
	M.put_in_hands(kitbox)
	disable_loadout_select(M)

/obj/item/storage/box/large
	icon = 'icons/effects/landmarks_static.dmi'
	icon_state = "loadout"

/obj/item/storage/box/large/ComponentInitialize() //same storage as a backpack, to allow it to hold loadout items
	. = ..()
	GET_COMPONENT(STR, /datum/component/storage)
	STR.max_combined_w_class = 21
	STR.max_w_class = WEIGHT_CLASS_NORMAL
	STR.max_items = 21

/datum/component/loadout_selector/ui_interact(mob/user, ui_key="loadout_select", datum/tgui/ui=null, force_open=0, datum/tgui/master_ui=null, datum/ui_state/state=GLOB.default_state)
	ui = SStgui.try_update_ui(user, src, ui_key, ui, force_open)
	if(!ui)
		ui = new(user, src, ui_key, "loadout_select", "Loadout Select", 800, 500, master_ui, state)
		ui.set_autoupdate(FALSE)
		//ui.set_style(ui_style)
		ui.open()

/datum/component/loadout_selector/ui_data(mob/user)
	var/list/data = list()
	data["outfits"] = data_names
	data["selected"] = selected_name
	if (selected_name)
		data["items"] = selected_items
		if(!(selected_datum.name in preview_images) || !(dir2text(selected_direction) in preview_images[selected_datum.name]))
			generate_previews()
		data["preview"] = preview_images[selected_datum.name][dir2text(selected_direction)]
	return data

/datum/component/loadout_selector/ui_act(action, params)
	if(..())
		return
	switch(action)
		if("loadout_select")
			select_outfit(params["name"])
			. = TRUE
		if("loadout_confirm")
		/*	if (selected_datum)			//Confirmation for loadout is bugged, can click a loadout multiple times then click finish multiple times.
				var/response = alert(usr, "Are you sure you wish to finish loadout selection? The currently selected outfit will be spawned in a box, which will be placed in your hand.", "Confirm Loadout Select", "Yes I'm done", "No, wait!")
				if (response == "Yes I'm done")
					finish()	*/
			finish()
			. = TRUE
		if("loadout_preview_direction")
			selected_direction = turn(selected_direction, 90 * text2num(params["direction"]))
			. = TRUE

//Selects an outfit and loads the preview of it
/datum/component/loadout_selector/proc/select_outfit(var/newname)
	//First of all, lets not do unnecessary work.
	//Don't reselect the one we already have selected
	if (newname == selected_name)
		return

	if (selected_datum)
		//If random is used, get rid of the generated previews so we'll regenerate them if we re-select this outfit
		if (selected_datum.contains_randomisation)
			preview_images[selected_datum.name] = null

		//Clean up old dummy/outfit
		QDEL_NULL(selected_datum)

	//Lets just make sure the desired outfit exists, too.
	//We do this after the cleanup so that we can pass null to deselect if desired
	if (!ispath(loadout_options[newname]))
		return

	//Ok we know we're selecting this, so
	selected_name = newname
	var/newtype = loadout_options[selected_name]
	selected_datum = new newtype
	selected_items = selected_datum.ui_data()

	generate_previews()
	spawn()
		if (usr)
			ui_interact(usr)

//This proc creates preview images for an outfit, if needed
/datum/component/loadout_selector/proc/generate_previews()
	//Lets make sure we have a parent mob and a player is connected
	if (!istype(parent, /mob))
		return

	//We need a client to send assets to
	var/mob/M = parent
	if (!M.client)
		return

	if (preview_images[selected_datum.name])
		return //The images have already been generated

	//They've not been made yet, lets do them. First of all, we make a mannequin based on the user's current appearance
	var/mob/living/carbon/human/dummy/mannequin = duplicate_human(M)

	//Secondly, we equip the currently selected outfit onto that mannequin
	selected_datum.equip(mannequin, visualsOnly = TRUE, overwrite = TRUE)

	COMPILE_OVERLAYS(mannequin)
	//mannequin.loc = M.loc //Debug

	//This is a mild hack, something is making dummies not initialise properly

	//Now we have our mannequin, photoshoot time!
	var/list/cached_icons = list()
	for (var/direction in GLOB.cardinals)
		var/icon/preview = getFlatIcon(mannequin, direction)

		preview.Scale(preview.Width() * 2.5, preview.Height() * 2.5)

		//If randomisation is involved, we use the datum ref instead of the mob ref, so it will change every time we select the outfit and make a new datum
		if (selected_datum.contains_randomisation)
			cached_icons[dir2text(direction)] = "\ref[selected_datum]_[selected_datum.name]_[direction].png"
		else
			cached_icons[dir2text(direction)] = "\ref[M]_[selected_datum.name]_[direction].png"
		//Use send_asset with verify = true, to load it to the client, this will sleep until it arrives, preventing missing images
		send_asset(M.client, cached_icons[dir2text(direction)], TRUE, preview)

	preview_images[selected_datum.name] = cached_icons

