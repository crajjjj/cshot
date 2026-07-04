ScriptName CS2SexLabScript Extends Quest


CS2GameScript Property Main Auto
CS2ConfigScript Property Config Auto
SexLabFramework Property SexLab Auto
;/sslAnimationSlots Property AnimSlots Auto
sslBaseAnimation[] animList0
sslBaseAnimation[] animList1
sslBaseAnimation[] animList2
sslBaseAnimation[] animList3
sslBaseAnimation[] animList4
sslBaseAnimation[] animList5
sslBaseAnimation[] animList6
Int numRegAnims  ; mirrors Config.numRegAnimsSL for speedup
Int animsPerPage  ; mirrors Config.animsPerPage
Form rules  ; mirrors Config.CS2EjaculationRulesSL
String rulesFile = "Cumshot/SLRulesDefaults"
String customRulesFile = "Cumshot/SLRulesCustom"/;


; --------------------------------------------------------------------
;                          Initialization
; --------------------------------------------------------------------

; first-time initialization
Event OnInit()
	Initialize()
	Main.DebugMessage("CS2 SexLab handler: Initialized (OnInit)")
EndEvent

; called on every game load
Function InitOnLoad()
	Initialize()
	Main.DebugMessage("CS2 SexLab handler: Initialized (InitOnLoad)")
EndFunction

Function Initialize()
	RegisterForModEvent("SexLabOrgasm", "OrgasmSL")
	RegisterForModEvent("SexLabOrgasmSeparate", "OrgasmSLSO")
	RegisterForModEvent("HookOrgasmStart", "OrgasmSLAll")
	RegisterForModEvent("HookOrgasmEnd", "CleanUpSL")
	RegisterForModEvent("HookAnimationEnding", "CleanUpSL")
	;RegisterForModEvent("CS2RequestRebuildSL", "RebuildAnimListSL")
	;RegisterForModEvent("CS2RequestSaveCustomSL", "SaveCustomRules")
	;Config.rebuilding = True
	;RebuildAnimListSL()
EndFunction


; --------------------------------------------------------------------
;                       SexLab event handlers
; --------------------------------------------------------------------

; orgasm handler for individual actors, supports multiple orgasms in a scene
Event OrgasmSL(Form actorForm, Int enjoyment, Int orgasmCount)
	Actor orgasmee = actorForm as Actor
	SexLabThread slScene = SexLab.GetThreadByActor(orgasmee)
	If !slScene
		Return
	EndIf

	
	;If doesOrgasm
		If ShouldEjaculate(slScene, orgasmee)
			Form cumObject = StorageUtil.PluckFormValue(orgasmee, "CS2_ejaculating")
			If cumObject
				; don't fully remove, it will cause NPCs to redress on second ejaculation during a scene
				orgasmee.UnequipItem(cumObject, abPreventEquip = True, abSilent = True)
			EndIf
			Main.Ejaculate(orgasmee)
		EndIf
		StorageUtil.SetFloatValue(orgasmee, "CS2_LastOrgasmTime", Utility.GetCurrentGameTime())
	;EndIf
EndEvent


; for legacy orgasm detection modes: assume that everyone cums at final stage
Event OrgasmSLAll(Int tid, Bool hasPlayer)
	If Config.orgasmDetectMode == 0
		Return  ; orgasms are only tracked individually, don't do this
	EndIf
	SexLabThread slScene = SexLab.GetThread(tid)
	Actor[] actorList = slScene.GetPositions()
	Int actorCount = actorList.Length
	Main.DebugMessage("CS2: Final stage orgasm for " + SexlabRegistry.GetSceneName(slScene.GetActiveScene()) + " (" + actorCount + " actors)", False)
	Int i = 0
	While i < actorCount
		OrgasmSL(actorList[i] as Form, -1, -1)
		i += 1
	EndWhile
EndEvent


; orgasm handler for the SexLab Separate Orgasm mod - just a wrapper for the main SL orgasm handler
Event OrgasmSLSO(Form actorForm, Int threadID)
	OrgasmSL(actorForm, -2, -2)
EndEvent


; remove cumshots on every actor when a scene has ended
Event CleanUpSL(Int tid, Bool hasPlayer)
	SexLabThread slScene = SexLab.GetThread(tid)
	Actor[] actorList = slScene.GetPositions()
	Int actorCount = actorList.Length
	Main.DebugMessage("CS2: Clean up cumshots for " + SexlabRegistry.GetSceneName(slScene.GetActiveScene()) + " (" + actorCount + " actors)", False)
	Float delay = Config.equipDelay  ; if for some reason cum is added after the scene's OrgasmEnd event
	Int i = 0
	While i < actorCount
		Main.RemoveCumshot(actorList[i], waitTime = delay, forceRemove = True)
		i += 1
	EndWhile
EndEvent


; --------------------------------------------------------------------
;                       SexLab animation management
; --------------------------------------------------------------------


;/ Rebuild the list of animations, they might have changed
Function RebuildAnimListSL()
	animsPerPage = Config.animsPerPage
	rules = Config.CS2EjaculationRulesSL
	numRegAnims = AnimSlots.Slotted
	If numRegAnims > 750
		numRegAnims = 750  ; max number of animations currently supported
	EndIf
	Config.numRegAnimsSL = numRegAnims
	Config.animRegSL = Utility.CreateStringArray(numRegAnims)
	Config.animNameSL = Utility.CreateStringArray(numRegAnims)
	Config.animValSL = Utility.CreateIntArray(numRegAnims)
	Config.animPosCountSL = Utility.CreateIntArray(numRegAnims)
	
	If numRegAnims == 0  ; SexLab hasn't initialized its animations yet, might happen on new install / update
		Config.defaultRulesSet == False
	ElseIf !Config.defaultRulesSet
		If Config.forceClearRules
			StorageUtil.debug_DeleteValues(rules)
			Config.forceClearRules = False
		EndIf
		ReadRulesFile(rulesFile)  ; pre-set rules for known animations that don't follow standard behavior
		If JsonUtil.JsonExists(customRulesFile)
			ReadRulesFile(customRulesFile)  ; custom rules that have been saved to a file, can overwrite some default rules
		EndIf
		Config.defaultRulesSet = True
	EndIf
	
	animList0 = AnimSlots.GetSlots(1, animsPerPage)
	animList1 = AnimSlots.GetSlots(2, animsPerPage)
	animList2 = AnimSlots.GetSlots(3, animsPerPage)
	animList3 = AnimSlots.GetSlots(4, animsPerPage)
	animList4 = AnimSlots.GetSlots(5, animsPerPage)
	animList5 = AnimSlots.GetSlots(6, animsPerPage)
	animList6 = AnimSlots.GetSlots(7, animsPerPage)

	sslBaseAnimation anim
	Int i = 0
	While i < numRegAnims
		anim = GetAnimation(i)
		Config.animRegSL[i] = anim.Registry
		Config.animNameSL[i] = anim.Name
		Config.animPosCountSL[i] = anim.PositionCount
		Config.animValSL[i] = StorageUtil.GetIntValue(rules, anim.Registry, -1)
		i += 1
	EndWhile

	Config.rebuilding = False
	Main.DebugMessage("SexLab animation list rebuilt", False)
EndFunction


Function ReadRulesFile(String pRulesFile)
	Int numRules = JsonUtil.PathCount(pRulesFile, ".rules")
	String[] animRegs = JsonUtil.PathMembers(pRulesFile, ".rules")
	Int i = 0
	While i < numRules
		StorageUtil.SetIntValue(rules, animRegs[i], JsonUtil.GetPathIntValue(pRulesFile, ".rules." + animRegs[i]))
		i += 1
	EndWhile
EndFunction


Function SaveCustomRules()
	JsonUtil.ClearPath(customRulesFile, ".rules")
	String animReg
	Int value
	Int defaultValue
	Int i = 0
	While i < numRegAnims
		animReg = Config.animRegSL[i]
		value = StorageUtil.GetIntValue(rules, animReg, -1)
		defaultValue = JsonUtil.GetPathIntValue(rulesFile, ".rules." + animReg, -1)
		If value != defaultValue
			JsonUtil.SetPathIntValue(customRulesFile, ".rules." + animReg, value)
		EndIf
		i += 1
	EndWhile
	JsonUtil.Save(customRulesFile)
	Main.DebugMessage("Custom ejaculation rules saved.")
EndFunction


sslBaseAnimation Function GetAnimation(Int index)
	Int list = index / animsPerPage
	Int i = index % animsPerPage
	If list == 0
		Return animList0[i]
	ElseIf list == 1
		Return animList1[i]
	ElseIf list == 2
		Return animList2[i]
	ElseIf list == 3
		Return animList3[i]
	ElseIf list == 4
		Return animList4[i]
	ElseIf list == 5
		Return animList5[i]
	ElseIf list == 6
		Return animList6[i]
	EndIf
endFunction


Int Function AnimationIndex(string anim)
	Int i
	i = animList0.Find(anim)
	If i >= 0
		Return i
	EndIf
	i = animList1.Find(anim)
	If i >= 0
		Return animsPerPage + i
	EndIf
	i = animList2.Find(anim)
	If i >= 0
		Return animsPerPage * 2 + i
	EndIf
	i = animList3.Find(anim)
	If i >= 0
		Return animsPerPage * 3 + i
	EndIf
	i = animList4.Find(anim)
	If i >= 0
		Return animsPerPage * 4 + i
	EndIf   
	i = animList5.Find(anim)
	If i >= 0
		Return animsPerPage * 5 + i
	EndIf   
	i = animList6.Find(anim)
	If i >= 0
		Return animsPerPage * 6 + i
	EndIf   
	Return -1
EndFunction/;




; Decide whether to show the external cumshot for this orgasm.
; When the penis is inside a partner the effect clips through the body, so only the contained
; animated mesh (ejaculationMode 1) may show there - and only if the MCM "Ejaculate while
; penetrating" toggle allows it. The "shooting" modes (particles, drops, projectiles) always
; stay hidden while inside, since they spray outward through the body.
Bool Function ShouldEjaculate(SexLabThread slScene, Actor a)
	If !PenisIsInside(slScene, a)
		return true  ; external finish (handjob / footjob / titfuck / pull-out) - always show
	EndIf
	return Config.ejaculationMode == 1 && Config.ejacWhileInside
EndFunction

; Returns true when the orgasming actor's penis is currently inside a partner (mouth/deepthroat,
; vagina, or anus) via SexLab P+'s framework-native per-actor interaction detection.
Bool Function PenisIsInside(SexLabThread slScene, Actor a)
	return slScene.IsOralComplex(a) || slScene.IsVaginalComplex(a) || slScene.IsAnalComplex(a)
EndFunction