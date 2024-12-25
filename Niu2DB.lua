-- @Author: ZhuL
-- @Date:   2017-05-02 11:03:16
-- @Last Modified by:   ZhuL
-- @Last Modified time: 2017-06-21 15:00:05

local M = class("NiuDB")

function M:ctor()
    self:init()
end

function M:init()
    self._curRoomId = nil

    self._curRoomType = nil

    self._banker = nil

    self._recordLst = nil

    -- -- 对手数据
    self._competitorData = nil
    --     player_id = 123456,
    --     facelook = 10002,
    --     vip_lv = 5,
    --     name = "SB",
    --     coin = 8989898,
    --     isBanker = false,
    --     isOK = false,
    -- }

    self._myData = {
        player_id = Game.playerDB:getPlayerUid(),
        facelook = Game.playerDB:getFacelook(),
        vip_lv = Game.playerDB:getVipLv(),
        name = Game.playerDB:getPlayerNick(),
        coin = Game.playerDB:getPlayerCoin(),
        isBanker = false,
        isOK = false,
    }

    self._myCards = {}

    -- 第一个数据为当前场，第二个数据为总数
    self._mySettle = {0 , 0}

    -- 第一个数据为当前场，第二个数据为总数
    self._cmpttSettle = {0 , 0}

    self._bet = 0

    self._banker = nil
end

function M:setRoomId(val)
    self._curRoomId = val
end

function M:getRoomId()
    return self._curRoomId
end

function M:reset(flag)
    print("data reset---------------------")

    if flag ~= false then
        self:resetMyData()
    end

    self._banker = nil

    self._competitorData = nil

    self._myCards = {}

    self._bet = 0

end

function M:resetMyData()
    print("resetMyData")
    print(debug.traceback())
    self._myData = {
        player_id = Game.playerDB:getPlayerUid(),
        facelook = Game.playerDB:getFacelook(),
        vip_lv = Game.playerDB:getVipLv(),
        name = Game.playerDB:getPlayerNick(),
        coin = Game.playerDB:getPlayerCoin(),
        isBanker = false,
        isOK = false,
        bHasShow = false
    }
end

function M:resetCmpttData()
    if self._competitorData then
        self._competitorData.isOK = false
    end
end

-- -- deprecated
-- function M:resetSettle()
--     self._mySettle = {0 , 0}
--     self._cmpttSettle = {0 , 0}
-- end

-- -- deprecated
-- function M:getMySettle()
--     return self._mySettle
-- end

-- -- deprecated
-- function M:getComptitorSettle()
--     return self._cmpttSettle
-- end

function M:setComptitorData(info)
    self._competitorData = info
    self._competitorData.isOK = info.is_ok == 0
end

function M:setBet(val , uid)
    if uid == self._myData.player_id then
        self._myData.coin = self._myData.coin - val
    elseif uid == self._competitorData.player_id then
        self._competitorData.coin = self._competitorData.coin - val
    end
    self._bet = val
end

function M:getCmpCoin()
    if self._competitorData then
        return self._competitorData.coin
    end
    return 0
end

function M:setMyCards(cards)
    if self._myData then
        self._myData.cards = cards
    end
end

function M:playerShow(uid)
    for __ , data in pairs({self._myData , self._competitorData}) do
        if uid == data.player_id then
            data.bHasShow = true
        end
    end
end

function M:hasShow(uid)
    for __ , data in pairs({self._myData , self._competitorData}) do
        if uid == data.player_id then
            return data.bHasShow
        end
    end
end

function M:getMyCards()
    if self._myData then
        return self._myData.cards
    end
    return {}
end

function M:getBet()
    return self._bet
end

function M:setPlayerCards(uid , cards)
    local myId = Game.playerDB:getPlayerUid()
    if uid == myId then
        self._myData.cards = cards
    else
        self._competitorData.cards = cards
    end
end

function M:setBanker(val)
    self._banker = val
end

function M:setReady(uid , val)
    if val == nil then
        val = true
    end
    if uid == Game.playerDB:getPlayerUid() then
        self._myData.isOK = val
    elseif self._competitorData then
        self._competitorData.isOK = val
    end
end

function M:getComptitorData()
    return self._competitorData
end

function M:getBanker()
    return self._banker
end

function M:getMyData()
    return self._myData
end

function M:addCoin(uid , coin)
    local myId = Game.playerDB:getPlayerUid()
    local data = uid == myId and self._myData or self._competitorData
    if data then
        data.coin = data.coin + coin
    end
end

function M:setCoin(uid , coin)
    local myId = Game.playerDB:getPlayerUid()
    local data = uid == myId and self._myData or self._competitorData
    if data then
        data.coin = coin
    end
end

-- 结算历史记录
function M:setRecord(lst)
    self._recordLst = lst
end

function M:resetRecord()
    self._recordLst = nil
end

function M:resetCmpttRecord()
    if type(self._recordLst) ~= "table" then
        return
    end
    local uid = Game.playerDB:getPlayerUid()
    for i , val in pairs(self._recordLst) do
        if uid ~= val.player_id then
            self._recordLst[i] = nil
            return
        end
    end
end

function M:getMyRecord()
    if self._recordLst == nil then
        return
    end
    local uid = Game.playerDB:getPlayerUid()
    for __ , val in pairs(self._recordLst) do
        if uid == val.player_id then
            return val
        end
    end
end

function M:getCmpttRecord()
    if self._recordLst == nil then
        return
    end
    local uid = Game.playerDB:getPlayerUid()
    for __ , val in pairs(self._recordLst) do
        if uid ~= val.player_id then
            return val
        end
    end
end

function M:setResult(info)
    local uid = Game.playerDB:getPlayerUid()
    local bWin = info.win_player_id == uid
    local data

    data = self._myData
    data.bWin = bWin
    data.cards = bWin and info.win_cards or info.lost_cards
    data.settleCoin = bWin and info.win_chouma or info.lost_chouma

    data = self._competitorData
    data.bWin = not bWin
    data.cards = bWin and info.lost_cards or info.win_cards
    data.settleCoin = bWin and info.lost_chouma or info.win_chouma

    local factor = bWin and 1 or -1
    local settle = self._mySettle
    settle[1] = self._myData.settleCoin * factor
    settle[2] = settle[2] + settle[1]

    settle = self._cmpttSettle
    factor = -factor
    settle[1] = self._competitorData.settleCoin * factor
    settle[2] = settle[2] + settle[1]

end

return M.new()