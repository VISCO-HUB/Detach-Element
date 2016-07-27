/*  
[INFO] 

NAME = Detach Element
VERSION = 1.0.3
AUTHOR = MastaMan
DEV = Visco CG
HELP = 

[INSTALL]

MACRO=DetachElement
CAT=VISCO
TEXT=Detach Element
ICON=#("FileLinkActionItems", 5)

[1.0.0]

* First release =

[1.0.1]

- BugFix: 3Ds Max hanging=
- BugFix: Overflow undo buffer=
* Link to parent objects=

[1.02]

- BugFix: Dummy layer set=
+ Added: Dummy transform same as parent transform=

[1.0.3]

* Crete new layer only for dummies not for parent objects=

[ABOUT]

This script helps to quickly break elements to new objects.=

[TEST]

[SCRIPT]
*/	


fn getScriptInfo s releaseInfo: "" =
(		
	if(releaseInfo != "") do
	(
		r = getINISetting s releaseInfo
		return r
	)
	
	v = getINISetting s "INFO" "VERSION"
	a = getINISetting s "INFO" "AUTHOR"
	n = getINISetting s "INFO" "NAME"
	o = getINISetting s "ABOUT"
	c = getINISetting s "INFO" "DEV"
	h = getINISetting s "INFO" "HELP"
	
	r = for i in (getINISetting s) where i != "ABOUT" and i != "SCRIPT" and i != "COPY" collect i
	
	return #(n, a, v, o, r, c, h)
)


fn parseToLine m = 
(
	if(m.count == 0) do return ""
	
	l = ""				
	for i in m do l += i + "\n"
	return l
)

fn useSettings k p w =
(	
	d = getFilenamePath  (getThisScriptFilename())
	n = filenameFromPath (getThisScriptFilename())			
	settingsFile = d + @"ini\" + (sysInfo.username) + "_" + n + ".ini"
	szUser = sysInfo.computername
	case w of
	(
		"r":
		(
			s = getINISetting settingsFile szUser k
			case p of
			(
				"int": return s as integer
				"float": return s as float
				"bool": if s == "true" then true else false
				default: return s
			)
		)
		default: return setINISetting settingsFile szUser k (p as string)
	)
)

rollout  _rDetachElement "Render Element" 
(
	group "Base Options"
	(
		checkbox cbxKeepSourceObject "Keep source object" tooltip: "Delete or not original object?"
		checkbox cbxCreateDummy "Create dummy for each object elementns"
	)
	
	group "Layer"
	(
		checkbox cbxCreateLayer "Create layer for new objects" tooltip: "Put detached elements to a separete layer?"
		edittext edtLayerName "" text: "fragments" enabled: false bold: true
	)
	
	group "Parent"
	(
		checkbox cbxCreateLayerParent "Create layer for dummies"
		edittext edtLayerParentName "" text: "controllers" enabled: false  bold: true
	)
	
	button btnDetach "Detach" width: 230 height: 35 offset: [0, 15]
	
	timer tmrDetach "" active: false interval: 10
	
	fn detachElements o iCnt:1 = 
	(		
		objList = #()
		while (o.getNumFaces() != 0) do 
		(
			polyop.setFaceSelection o #{1}
			o.selectElement()

			el = polyop.getFaceSelection o
			n = o.name + "_" + (iCnt as string)
			
			polyop.detachFaces o el asNode:true name:n
			g = getNodeByName n
			
			append objList g
		
			iCnt += 1 
		)	

		return objList
	)
	
	fn addChildren o c = if(c != undefined and o != undefined) then for i in c do append o.children i else #()
	
	fn createLayer n = 
	(
		layer = LayerManager.getLayerFromName n			
		if(layer == undefined) do layer = LayerManager.newLayer()			
		layer.setname n
		
		return layer
	)
	
	fn addLayerNodes layer l =
	(
		if(l == undefined) do return false
		for i in l where i != undefined do layer.addnode i
	)
	
	on tmrDetach tick do
	(
		undo off
		(
			s = for i in selection where canConvertTo i Editable_Poly collect i
			
			-- Create layer
			layerNewObjects = undefined
			if(cbxCreateLayer.checked) do layerNewObjects = createLayer (edtLayerName.text)
			
			layerParentObjects = undefined
			if(cbxCreateLayerParent.checked) do layerParentObjects = createLayer (edtLayerParentName.text)
			
			progressStart "Detaching Elements..."
			escapeEnable
			disableSceneRedraw()
			
			iCount = 1
			for o in s where classOf o == Editable_Poly do
			(
				-- Get parent
				p = o.parent 
				
				-- Keep source object
				if(cbxKeepSourceObject.checked) do
				(
					maxOps.CloneNodes o newNodes: &newNodes
					o = newNodes[1]
				)
				
				-- Detach to elements
				convertToPoly o
				
				l = detachElements o
				
				-- Add children
				d = undefined
				if(cbxCreateDummy.checked) then
				(
					d = dummy()
					addChildren p d
										
					if(l.count > 0 and p == undefined) do d.transform = l[1].transform
					if(p != undefined) do d.transform = p.transform
					
					addChildren d l				
				)
				else
				(
					addChildren p l
				)
				
				if(cbxCreateLayer.checked and layerNewObjects != undefined) do addLayerNodes layerNewObjects l
				if(cbxCreateLayerParent.checked and layerParentObjects != undefined and p != undefined) do addLayerNodes layerParentObjects #(d)
				
				-- Remove empty original object
				delete o
				
				-- Set progress bar
				progressUpdate (100.0 * iCount / l.count)
				if(getProgressCancel() == true) do exit	
				iCount += 1
			)
			
			enableSceneRedraw()
			enableSceneRedraw()
			enableSceneRedraw()
			forceCompleteRedraw()
			
			progressEnd()
		)
		
		tmrDetach.active = false
	)
	
	on btnDetach pressed do
	(
		if(selection.count == 0) do return messageBox "Please select objects!" title: "Warning!"
				
		tmrDetach.active = true
	)
	
	on _rDetachElement open do
	(
		cbxKeepSourceObject.checked = useSettings "KEEPSOURCEOBJECT" "bool" "r"
		cbxCreateDummy.checked = useSettings "CREATEDUMMY" "bool" "r"
		cbxCreateLayer.checked = useSettings "CREATELAYER" "bool" "r"
		cbxCreateLayerParent.checked = useSettings "CREATELAYERPARENT" "bool" "r"
		
		edtLayerName.enabled = cbxCreateLayer.checked
		edtLayerParentName.enabled = cbxCreateLayerParent.checked
		
		t = useSettings "LAYERNAME" "string" "r"
		if(t != "") do edtLayerName.text = t
				
		
		t = useSettings "LAYERPARENTNAME" "string" "r"
		if(t != "") do edtLayerParentName.text = t
	)
	
	on cbxKeepSourceObject changed s do
	(
		useSettings "KEEPSOURCEOBJECT" s "w"
	)
	
	on cbxCreateDummy changed s do
	(
		useSettings "CREATEDUMMY" s "w"
	)
	
	on cbxCreateLayer changed s do
	(
		useSettings "CREATELAYER" s "w"
		edtLayerName.enabled = s
	)
	
	on cbxCreateLayerParent changed s do
	(
		useSettings "CREATELAYERPARENT" s "w"
		edtLayerParentName.enabled = s
	)
	
	on edtLayerName changed s do
	(
		useSettings "LAYERNAME" s "w"
	)
	
	on edtLayerParentName changed s do
	(
		useSettings "LAYERPARENTNAME" s "w"
	)
)


rollout _rAbout "About" 
(
	label lblName "" 
	label lblVer "" 
	
	label lblAuthor "" height: 30
	label lblCopy ""  height: 30
	
	on _rAbout open do
	(		
		i = getScriptInfo (getThisScriptFilename())
			
		lblName.caption = i[1]
		lblAuthor.caption = i[2]
		lblVer.caption = i[3]
		lblCopy.caption = i[6]
	)
)

try(closeRolloutFloater rDetachElement) catch()
global rDetachElement = newRolloutFloater "Detach Element" 250 320

addRollout _rDetachElement rDetachElement rolledUp:false 
addRollout _rAbout rDetachElement rolledUp:true 