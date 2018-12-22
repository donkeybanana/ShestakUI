local T, C, L, _ = unpack(select(2, ...))
if C.unitframe.enable ~= true or C.filger.enable ~= true then return end

----------------------------------------------------------------------------------------
--	Lightweight buff/debuff tracking (Filger by Nils Ruesch, editors Affli/SinaC/Ildyria)
----------------------------------------------------------------------------------------
P_BUFF_ICON_Anchor:SetPoint(unpack(C.position.filger.player_buff_icon))
P_BUFF_ICON_Anchor:SetSize(C.filger.buffs_size, C.filger.buffs_size)

P_PROC_ICON_Anchor:SetPoint(unpack(C.position.filger.player_proc_icon))
P_PROC_ICON_Anchor:SetSize(C.filger.buffs_size, C.filger.buffs_size)

SPECIAL_P_BUFF_ICON_Anchor:SetPoint(unpack(C.position.filger.special_proc_icon))
SPECIAL_P_BUFF_ICON_Anchor:SetSize(C.filger.buffs_size, C.filger.buffs_size)

T_DEBUFF_ICON_Anchor:SetPoint(unpack(C.position.filger.target_debuff_icon))
T_DEBUFF_ICON_Anchor:SetSize(C.filger.buffs_size, C.filger.buffs_size)

T_BUFF_Anchor:SetPoint(unpack(C.position.filger.target_buff_icon))
T_BUFF_Anchor:SetSize(C.filger.pvp_size, C.filger.pvp_size)

PVE_PVP_DEBUFF_Anchor:SetPoint(unpack(C.position.filger.pve_debuff))
PVE_PVP_DEBUFF_Anchor:SetSize(C.filger.pvp_size, C.filger.pvp_size)

PVE_PVP_CC_Anchor:SetPoint(unpack(C.position.filger.pve_cc))
PVE_PVP_CC_Anchor:SetSize(221, 25)

COOLDOWN_Anchor:SetPoint(unpack(C.position.filger.cooldown))
COOLDOWN_Anchor:SetSize(C.filger.cooldown_size, C.filger.cooldown_size)

T_DE_BUFF_BAR_Anchor:SetPoint(unpack(C.position.filger.target_bar))
T_DE_BUFF_BAR_Anchor:SetSize(218, 25)

SpellActivationOverlayFrame:SetFrameStrata("BACKGROUND")

local Filger = {}
local MyUnits = {player = true, vehicle = true, pet = true}
local SpellGroups = {}

-- _G.Filger = Filger -- Check cpu

function Filger:TooltipOnEnter()
	if self.spellID > 20 then
		local str = "spell:%s"
		GameTooltip:ClearLines()
		GameTooltip:SetOwner(self, "ANCHOR_TOPRIGHT", 0, 3)
		GameTooltip:SetHyperlink(format(str, self.spellID))
		GameTooltip:Show()
	end
end

function Filger:TooltipOnLeave()
	GameTooltip:Hide()
end

function Filger:UnitAura(unitID, inSpellID, spell, filter, absID)
	if absID then
		for i = 1, 40 do
			local name, icon, count, _, duration, expirationTime, unitCaster, _, _, spellID = UnitAura(unitID, i, filter)
			if not name then break end
			if spellID == inSpellID then
				return name, spellID, icon, count, duration, expirationTime, unitCaster
			end
		end
	else
		local name, icon, count, _, duration, expirationTime, unitCaster, _, _, spellID = AuraUtil.FindAuraByName(spell, unitID, filter)
		if name then
			return name, spellID, icon, count, duration, expirationTime, unitCaster
		end
	end
end

function Filger:UpdateCD()
	local time = self.value.start + self.value.duration - GetTime()

	if self:GetParent().Mode == "BAR" then
		self.statusbar:SetValue(time)
		if time <= 60 then
			self.time:SetFormattedText("%.1f", time)
		else
			self.time:SetFormattedText("%d:%.2d", time / 60, time % 60)
		end
	else
		if time < 0 then
			local frame = self:GetParent()
			frame.actives[self.value.spid] = nil
			self:SetScript("OnUpdate", nil)
			Filger.DisplayActives(frame)
		end
	end
end

function Filger:DisplayActives()
	if not self.actives then return end
	if not self.bars then self.bars = {} end
	local id = self.Id
	local index = 1
	local previous = nil

	for _, _ in pairs(self.actives) do
		local bar = self.bars[index]
		if not bar then
			bar = CreateFrame("Frame", "FilgerAnchor"..id.."Frame"..index, self)
			bar:SetScale(1)
			bar:SetTemplate("Default")

			if index == 1 then
				bar:SetPoint(unpack(self.Position))
			else
				if self.Direction == "UP" then
					bar:SetPoint("BOTTOM", previous, "TOP", 0, self.Interval)
				elseif self.Direction == "RIGHT" then
					bar:SetPoint("LEFT", previous, "RIGHT", self.Mode == "ICON" and self.Interval or (self.BarWidth + self.Interval + 7), 0)
				elseif self.Direction == "LEFT" then
					bar:SetPoint("RIGHT", previous, "LEFT", self.Mode == "ICON" and -self.Interval or -(self.BarWidth + self.Interval + 7), 0)
				else
					bar:SetPoint("TOP", previous, "BOTTOM", 0, -self.Interval)
				end
			end

			if bar.icon then
				bar.icon = _G[bar.icon:GetName()]
			else
				bar.icon = bar:CreateTexture("$parentIcon", "BORDER")
				bar.icon:SetPoint("TOPLEFT", 2, -2)
				bar.icon:SetPoint("BOTTOMRIGHT", -2, 2)
				bar.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
			end

			if self.Mode == "ICON" then
				if bar.cooldown then
					bar.cooldown = _G[bar.cooldown:GetName()]
				else
					bar.cooldown = CreateFrame("Cooldown", "$parentCD", bar, "CooldownFrameTemplate")
					bar.cooldown:SetAllPoints(bar.icon)
					bar.cooldown:SetReverse(true)
					bar.cooldown:SetFrameLevel(3)
				end

				if bar.count then
					bar.count = _G[bar.count:GetName()]
				else
					bar.count = bar:CreateFontString("$parentCount", "OVERLAY")
					bar.count:SetFont(C.font.cooldown_timers_font, C.font.cooldown_timers_font_size, C.font.cooldown_timers_font_style)
					bar.count:SetShadowOffset(C.font.cooldown_timers_font_shadow and 1 or 0, C.font.cooldown_timers_font_shadow and -1 or 0)
					bar.count:SetPoint("BOTTOMRIGHT", 1, -2)
					bar.count:SetJustifyH("RIGHT")
				end
			else
				if bar.statusbar then
					bar.statusbar = _G[bar.statusbar:GetName()]
				else
					bar.statusbar = CreateFrame("StatusBar", "$parentStatusBar", bar)
					bar.statusbar:SetWidth(self.BarWidth)
					bar.statusbar:SetHeight(self.IconSize - 10)
					bar.statusbar:SetStatusBarTexture(C.media.texture)
					bar.statusbar:SetStatusBarColor(T.color.r, T.color.g, T.color.b, 1)
					if self.IconSide == "LEFT" then
						bar.statusbar:SetPoint("BOTTOMLEFT", bar, "BOTTOMRIGHT", 5, 2)
					elseif self.IconSide == "RIGHT" then
						bar.statusbar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", -5, 2)
					end
				end
				bar.statusbar:SetMinMaxValues(0, 1)
				bar.statusbar:SetValue(0)

				if bar.bg then
					bar.bg = _G[bar.bg:GetName()]
				else
					bar.bg = CreateFrame("Frame", "$parentBG", bar.statusbar)
					bar.bg:SetPoint("TOPLEFT", -2, 2)
					bar.bg:SetPoint("BOTTOMRIGHT", 2, -2)
					bar.bg:SetFrameStrata("BACKGROUND")
					bar.bg:SetTemplate("Default")
				end

				if bar.background then
					bar.background = _G[bar.background:GetName()]
				else
					bar.background = bar.statusbar:CreateTexture(nil, "BACKGROUND")
					bar.background:SetAllPoints()
					bar.background:SetTexture(C.media.texture)
					bar.background:SetVertexColor(T.color.r, T.color.g, T.color.b, 0.2)
				end

				if bar.time then
					bar.time = _G[bar.time:GetName()]
				else
					bar.time = bar.statusbar:CreateFontString("$parentTime", "OVERLAY")
					bar.time:SetFont(C.font.filger_font, C.font.filger_font_size, C.font.filger_font_style)
					bar.time:SetShadowOffset(C.font.filger_font_shadow and 1 or 0, C.font.filger_font_shadow and -1 or 0)
					bar.time:SetPoint("RIGHT", bar.statusbar, 0, 0)
					bar.time:SetJustifyH("RIGHT")
				end

				if bar.count then
					bar.count = _G[bar.count:GetName()]
				else
					bar.count = bar:CreateFontString("$parentCount", "OVERLAY")
					bar.count:SetFont(C.font.filger_font, C.font.filger_font_size, C.font.filger_font_style)
					bar.count:SetShadowOffset(C.font.filger_font_shadow and 1 or 0, C.font.filger_font_shadow and -1 or 0)
					bar.count:SetPoint("BOTTOMRIGHT", 1, 0)
					bar.count:SetJustifyH("RIGHT")
				end

				if bar.spellname then
					bar.spellname = _G[bar.spellname:GetName()]
				else
					bar.spellname = bar.statusbar:CreateFontString("$parentSpellName", "OVERLAY")
					bar.spellname:SetFont(C.font.filger_font, C.font.filger_font_size, C.font.filger_font_style)
					bar.spellname:SetShadowOffset(C.font.filger_font_shadow and 1 or 0, C.font.filger_font_shadow and -1 or 0)
					bar.spellname:SetPoint("LEFT", bar.statusbar, 2, 0)
					bar.spellname:SetPoint("RIGHT", bar.time, "LEFT")
					bar.spellname:SetJustifyH("LEFT")
				end
			end
			bar.spellID = 0
			self.bars[index] = bar
		end
		previous = bar
		index = index + 1
	end

	local temp = {}
	for _, value in pairs(self.actives) do
		table.insert(temp, value)
	end

	local function comp(element1, elemnet2)
		return element1.sort <= elemnet2.sort
	end
	table.sort(temp, comp)

	if not self.sortedIndex then self.sortedIndex = {} end

	for n in pairs(self.sortedIndex) do
		self.sortedIndex[n] = 999
	end

	local activeCount = 1
	local limit = (C.actionbar.button_size * 12)/self.IconSize
	for n in pairs(self.actives) do
		self.sortedIndex[activeCount] = n
		activeCount = activeCount + 1
		if activeCount > limit then activeCount = limit end
	end
	table.sort(self.sortedIndex)

	index = 1
	for activeIndex, value in pairs(temp) do
		if activeIndex >= activeCount then
			break
		end
		local bar = self.bars[index]
		bar.spellName = GetSpellInfo(value.spid)
		if self.Mode == "BAR" then
			bar.spellname:SetText(bar.spellName)
		end
		bar.icon:SetTexture(value.icon)
		if value.count and value.count > 1 then
			bar.count:SetText(value.count)
			bar.count:Show()
		else
			bar.count:Hide()
		end
		if value.duration and value.duration > 0 then
			if self.Mode == "ICON" then
				CooldownFrame_Set(bar.cooldown, value.start, value.duration, 1)
				if value.data.filter == "CD" or value.data.filter == "ICD" then
					bar.value = value
					bar:SetScript("OnUpdate", Filger.UpdateCD)
				else
					bar:SetScript("OnUpdate", nil)
				end
				bar.cooldown:Show()
			else
				bar.statusbar:SetMinMaxValues(0, value.duration)
				bar.value = value
				bar:SetScript("OnUpdate", Filger.UpdateCD)
			end
		else
			if self.Mode == "ICON" then
				bar.cooldown:Hide()
			else
				bar.statusbar:SetMinMaxValues(0, 1)
				bar.statusbar:SetValue(1)
				bar.time:SetText("")
			end
			bar:SetScript("OnUpdate", nil)
		end
		bar.spellID = value.spid
		if C.filger.show_tooltip then
			bar:EnableMouse(true)
			bar:SetScript("OnEnter", Filger.TooltipOnEnter)
			bar:SetScript("OnLeave", Filger.TooltipOnLeave)
		end
		bar:SetWidth(self.IconSize or C.filger.buffs_size)
		bar:SetHeight(self.IconSize or C.filger.buffs_size)
		bar:SetAlpha(value.data.opacity or 1)
		bar:Show()
		index = index + 1
	end

	for i = index, #self.bars, 1 do
		local bar = self.bars[i]
		bar:Hide()
	end
end

local LogEvents = {
	["SPELL_AURA_REMOVED"] = true,
	["SPELL_AURA_REMOVED_DOSE"] = true,
	["SPELL_AURA_APPLIED"] = true,
	["SPELL_AURA_APPLIED_DOSE"] = true,
	["SPELL_AURA_REFRESH"] = true,
	["SPELL_PERIODIC_DAMAGE"] = true,
	["SPELL_DAMAGE"] = true
}

local function GUIDRoles(uid)
	if uid == nil then
		return nil
	end
	local contians = false
	local result = {}
	if UnitGUID("player") == uid then
		result["player"] = true
		contians = true
	end
	if UnitGUID("target") == uid then
		result["target"] = true
		contians = true
	end
	if UnitGUID("pet") == uid then
		result["pet"] = true
		contians = true
	end
	if UnitGUID("focus") == uid then
		result["focus"] = true
		contians = true
	end
	if contians then
		return result
	end
	return nil
end

function Filger:OnEvent(event, unit, _, castID)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		local _, eventType, _, srcGUID, _, _, _, dstGUID = CombatLogGetCurrentEventInfo()
		if LogEvents[eventType] then
			local targets = GUIDRoles(dstGUID)
			local casters = GUIDRoles(srcGUID)
			if targets then
				local spellId, spellName = select(12, CombatLogGetCurrentEventInfo())
				local data = SpellGroups[self.Id].spells[spellName] or SpellGroups[self.Id].spells[spellId]
				if data and (data.caster == nil or (casters and casters[data.caster]) or data.caster == "all") and (targets[data.unitID] or data.unitID == nil) then
					if data.absID then
						data = SpellGroups[self.Id].spells[spellId]
					end
					local name, icon, count, duration, expirationTime, start, spid
					local ptt = GetSpecialization()
					local isTalent = data.talentID and select(10, GetTalentInfoByID(data.talentID))
					if (data.filter == "BUFF" or data.filter == "DEBUFF") and (not data.spec or data.spec == ptt) and (not data.talentID or isTalent) then
						if eventType ~= "SPELL_AURA_REMOVED" then
							local filter
							if data.filter == "BUFF" then
								filter = "HELPFUL"
							else
								filter = "HARMFUL"
							end
							name, spid, icon, count, duration, expirationTime, caster = Filger:UnitAura(data.unitID, data.spellID, spellName, filter, data.absID)
							if spid then
								if not data.count or count >= data.count then
									self.actives[spid] = {data = data, name = name, icon = icon, count = count, start = expirationTime - duration, duration = duration, spid = spid, sort = data.sort}
									self:RegisterEvent("UNIT_AURA")
								end
							end
						else
							self.actives[spellId] = nil
							self:UnregisterEvent("UNIT_AURA")
						end
						Filger.DisplayActives(self)
					end
				end
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" or event == "SPELL_UPDATE_COOLDOWN"
	or event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED"
	or event == "UNIT_AURA" and (unit == "player" or unit == "target" or unit == "pet" or unit == "focus")
	or (event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player") then
		for spid in pairs(self.actives) do
			self.actives[spid] = nil
		end

		local ptt = GetSpecialization()
		local needUpdate = false

		for i = 1, #C["filger_spells"][T.class][self.Id], 1 do
			local data = C["filger_spells"][T.class][self.Id][i]
			if C.filger.disable_cd == true and (data.filter == "CD" or (data.filter == "ICD" and data.trigger ~= "NONE")) then return end
			local found = false
			local name, icon, count, duration, start, spid
			local isTalent = data.talentID and select(10, GetTalentInfoByID(data.talentID))
			spid = 0

			if data.filter == "BUFF" and (not data.spec or data.spec == ptt) and (not data.talentID or isTalent) then
				local caster, spell, expirationTime
				spell = GetSpellInfo(data.spellID)
				if spell then
					name, spid, icon, count, duration, expirationTime, caster = Filger:UnitAura(data.unitID, data.spellID, spell, "HELPFUL", data.absID)
					if name and (data.caster ~= 1 and (caster == data.caster or data.caster == "all") or MyUnits[caster]) then
						if not data.count or count >= data.count then
							start = expirationTime - duration
							found = true
						end
					end
				end
			elseif data.filter == "DEBUFF" and (not data.spec or data.spec == ptt) and (not data.talentID or isTalent) then
				local caster, spell, expirationTime
				spell = GetSpellInfo(data.spellID)
				if spell then
					name, spid, icon, count, duration, expirationTime, caster = Filger:UnitAura(data.unitID, data.spellID, spell, "HARMFUL", data.absID)
					if name and (data.caster ~= 1 and (caster == data.caster or data.caster == "all") or MyUnits[caster]) then
						start = expirationTime - duration
						found = true
					end
				end
			elseif data.filter == "CD" and (not data.spec or data.spec == ptt) then
				if data.spellID then
					name, _, icon = GetSpellInfo(data.spellID)
					if name then
						if data.absID then
							start, duration = GetSpellCooldown(data.spellID)
						else
							start, duration = GetSpellCooldown(name)
						end
						spid = data.spellID
					end
				elseif data.slotID then
					spid = data.slotID
					local slotLink = GetInventoryItemLink("player", data.slotID)
					if slotLink then
						name, _, _, _, _, _, _, _, _, icon = GetItemInfo(slotLink)
						start, duration = GetInventoryItemCooldown("player", data.slotID)
					end
				end
				if name and (duration or 0) > 1.5 then
					found = true
				end
			elseif data.filter == "ICD" and (not data.spec or data.spec == ptt) then
				if data.trigger == "BUFF" then
					local spell
					spell, _, icon = GetSpellInfo(data.spellID)
					if spell then
						name, spid = Filger:UnitAura(data.unitID, data.spellID, spell, "HELPFUL", data.absID)
					end
				elseif data.trigger == "DEBUFF" then
					local spell
					spell, _, icon = GetSpellInfo(data.spellID)
					if spell then
						name, spid = Filger:UnitAura("player", data.spellID, spell, "HARMFUL", data.absID)
					end
				elseif data.trigger == "NONE" and event == "UNIT_SPELLCAST_SUCCEEDED" then
					if castID == data.spellID then
						name, _, icon = GetSpellInfo(data.spellID)
						spid = data.spellID
					end
				end
				if name then
					if data.slotID then
						local slotLink = GetInventoryItemLink("player", data.slotID)
						_, _, _, _, _, _, _, _, _, icon = GetItemInfo(slotLink)
					end
					duration = data.duration
					start = GetTime()
					found = true
				end
			end

			if found then
				if not self.actives[spid] then
					self.actives[spid] = {data = data, name = name, icon = icon, count = count, start = start, duration = duration, spid = spid, sort = data.sort}
					needUpdate = true
					if T.class == "DEATHKNIGHT" and self.actives[spid].duration == 10 and data.filter == "CD" then
						self.actives[spid] = nil
					end
				else
					if data.filter ~= "ICD" and (self.actives[spid].count ~= count or self.actives[spid].start ~= start or self.actives[spid].duration ~= duration) then
						self.actives[spid].count = count
						self.actives[spid].start = start
						self.actives[spid].duration = duration
						needUpdate = true
					end
				end
			else
				if data.filter ~= "ICD" and self.actives and self.actives[spid] then
					if event == "UNIT_SPELLCAST_SUCCEEDED" then return end
					self.actives[spid] = nil
					needUpdate = true
				end
			end
		end

		if self.actives then
			Filger.DisplayActives(self)
		end
	end
end

if C["filger_spells"] and C["filger_spells"]["ALL"] then
	if not C["filger_spells"][T.class] then
		C["filger_spells"][T.class] = {}
	end

	for i = 1, #C["filger_spells"]["ALL"], 1 do
		local merge = false
		local spellListAll = C["filger_spells"]["ALL"][i]
		local spellListClass = nil
		for j = 1, #C["filger_spells"][T.class], 1 do
			spellListClass = C["filger_spells"][T.class][j]
			local mergeAll = spellListAll.Merge or false
			local mergeClass = spellListClass.Merge or false
			if spellListClass.Name == spellListAll.Name and (mergeAll or mergeClass) then
				merge = true
				break
			end
		end
		if not merge or not spellListClass then
			table.insert(C["filger_spells"][T.class], C["filger_spells"]["ALL"][i])
		else
			for j = 1, #spellListAll, 1 do
				table.insert(spellListClass, spellListAll[j])
			end
		end
	end
end

if T.CustomFilgerSpell then
	for _, data in pairs(T.CustomFilgerSpell) do
		for class, _ in pairs(C["filger_spells"]) do
			if class == T.class then
				for i = 1, #C["filger_spells"][class], 1 do
					if C["filger_spells"][class][i]["Name"] == data[1] then
						table.insert(C["filger_spells"][class][i], data[2])
					end
				end
			end
		end
	end
end

if C["filger_spells"] and C["filger_spells"][T.class] then
	for index in pairs(C["filger_spells"]) do
		if index ~= T.class then
			C["filger_spells"][index] = nil
		end
	end

	local idx = {}
	for i = 1, #C["filger_spells"][T.class], 1 do
		local jdx = {}
		local data = C["filger_spells"][T.class][i]
		local group = {spells = {}}

		for j = 1, #data, 1 do
			local spell
			local id
			if data[j].spellID then
				spell = GetSpellInfo(data[j].spellID)
			else
				local slotLink = GetInventoryItemLink("player", data[j].slotID)
				if slotLink then
					spell = GetItemInfo(slotLink)
				end
			end
			if spell then
				local id
				if data[j].absID then
					id = data[j].spellID or data[j].slotID
				else
					id = GetSpellInfo(data[j].spellID) or data[j].slotID
				end
				data[j].sort = j
				group.spells[id] = data[j]
			end
			if not spell and not data[j].slotID then
				print("|cffff0000WARNING: spell/slot ID ["..(data[j].spellID or data[j].slotID or "UNKNOWN").."] no longer exists! Report this to Shestak.|r")
				table.insert(jdx, j)
			end
		end

		for _, v in ipairs(jdx) do
			table.remove(data, v)
		end

		group.data = data
		table.insert(SpellGroups, i, group)

		if #data == 0 then
			print("|cffff0000WARNING: section ["..data.Name.."] is empty! Report this to Shestak.|r")
			table.insert(idx, i)
		end
	end

	for _, v in ipairs(idx) do
		table.remove(C["filger_spells"][T.class], v)
	end

	for i = 1, #SpellGroups, 1 do
		local data = SpellGroups[i].data
		local frame = CreateFrame("Frame", "FilgerFrame"..i.."_"..data.Name, T_PetBattleFrameHider)
		frame.Id = i
		frame.Name = data.Name
		frame.Direction = data.Direction or "DOWN"
		frame.IconSide = data.IconSide or "LEFT"
		frame.Mode = data.Mode or "ICON"
		frame.Interval = data.Interval or 3
		frame:SetAlpha(data.Alpha or 1)
		frame.IconSize = data.IconSize or C.filger.buffs_size
		frame.BarWidth = data.BarWidth or 186
		frame.Position = data.Position or "CENTER"
		frame:SetPoint(unpack(data.Position))
		frame.actives = {}

		if C.filger.test_mode then
			frame.actives = {}
			for j = 1, math.min(C.filger.max_test_icon, #C["filger_spells"][T.class][i]), 1 do
				local data = C["filger_spells"][T.class][i][j]
				local name, icon
				if data.spellID then
					name, _, icon = GetSpellInfo(data.spellID)
				elseif data.slotID then
					local slotLink = GetInventoryItemLink("player", data.slotID)
					if slotLink then
						name, _, _, _, _, _, _, _, _, icon = GetItemInfo(slotLink)
					end
				end
				frame.actives[j] = {data = data, name = name, icon = icon, count = 9, start = 0, duration = 0, spid = data.spellID or data.slotID, sort = data.sort}
			end
			Filger.DisplayActives(frame)
		else
			for j = 1, #C["filger_spells"][T.class][i], 1 do
				local data = C["filger_spells"][T.class][i][j]
				if data.filter == "CD" then
					frame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
					break
				elseif data.trigger == "NONE" then
					frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
					break
				end
			end
			frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
			frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
			frame:RegisterEvent("PLAYER_TARGET_CHANGED")
			frame:RegisterEvent("PLAYER_ENTERING_WORLD")
			frame:SetScript("OnEvent", Filger.OnEvent)
		end
	end
end