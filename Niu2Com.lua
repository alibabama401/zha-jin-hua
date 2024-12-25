-- @Author: ZhuL
-- @Date:   2017-05-02 11:03:07
-- @Last Modified by:   ZhuL
-- @Last Modified time: 2017-06-22 17:57:47

--[[
    处理逻辑，表情，弹幕等等
]]

local BaseCom = require_ex("data.BaseCom")
local M = class("NiuCom" , BaseCom)

local GameState = {
    Idle = 0,
    Running = 1,
}

local State = {
    Ready = 1,
    Player1Rob = 2,
    Player2Rob = 3,
    WaitBet = 4,    -- 等待押注
    WaitSettle = 5,  -- 等待亮牌
    Idle = 6
}

function M:ctor()
    BaseCom.ctor(self)

    self._DB = require("games.niu2.models.Niu2DB")

    self._gameCallbacks = nil

    self.__state = nil

    self.__needClear = false

    self:init()
end

function M:init()
    self._gameCallbacks = {
        [71001] = function(pack)
            local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_player")
            print("-- 71001 进入房间后对方玩家信息")
            dump(info)
            self:onPlayerEnterRoom(info)
        end,
        [71005] = function(pack)
            local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_zhuangjia")
            print("-- 71005 确定庄家推送")
            dump(info)
            self:confirmBanker(info)
        end,
        [71007] = function(pack)
            local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_send_cards")
            print("-- 71007 发牌")
            dump(info)

            self:onDispatchPoker(info)
        end,
        [71009] = function(pack)
            local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_end")
            print("-- 71009 结算")
            dump(info)
            self:onResult(info)
        end,
        [71003] = function(pack)
            local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_can_qiangzhuang")
            print("-- 71003 通知抢庒")
            dump(info)

            self:noticeRobBanker(info)
        end,
        [71002] = function(pack)
            local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_ok")
            print("-- 71002 玩家准备")
            dump(info)

            self:respReady(info)
        end,
        [71004] = function(pack)
            local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_qiangzhuang")
            print("-- 71004 抢庄")
            dump(info)

        end,
        [71008] = function(pack)
            local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_show_cards")
            print("亮牌")
            dump(info)

            self:respShow(info)
        end,
        [71006] = function(pack)
            local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_yazhu")
            print("押注")
            dump(info)

            self:respBet(info)
        end,
        [71010] = function(pack)
            local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_quit")
            print("退出2牛房间")
            dump(info)
            self:exitGame(info)
        end,
        [71011] = function(pack)
            local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_room_state")
            print("同步房间数据")
            dump(info)

            self:refreshRoomData(info)
        end,
        [71013] = function(pack)
            local info , cursor = netCom.parsePackByProtocol(pack , cursor , "s2c_2niu_history")
            print("7101371013")

            dump(info)
            self:refreshRecord(info)
        end
    }
end

-- 刷新历史数据
function M:refreshRecord(info)
    self._DB:setRecord(info.history)
    self:call("Niu2View" , "refreshRecord")
end

function M:refreshRoomData(info)
    self._DB:setComptitorData(info.player_info[1])
    self:setGameState(info.room_state)

    print("____________________________")
    dump(self._DB:getComptitorData())

    self._DB:setBanker(info.zhuangjia)

    local p1 = info.qz_player1
    local p2 = info.qz_player2

    self._DB:setMyCards(info.cards)

    local free = info.zhuangjia == p1 and p2 or p1

    self._DB:setBet(info.chouma , free)

    self:refreshView("Niu2View")

    local uid = Game.playerDB:getPlayerUid()
    if info.room_state == State.Ready then
        self:call("Niu2View" , "onPlayerAll" , info.lefttime)
    elseif info.room_state == State.Player1Rob then
        self:call("Niu2View" , "onNoticeRobBanker" , p1 == uid , info.lefttime)
    elseif info.room_state == State.Player2Rob then
        self:call("Niu2View" , "onNoticeRobBanker" , p2 == uid , info.lefttime)
    elseif info.room_state == State.WaitBet then
        self:call("Niu2View" , "onConfirmBanker" , info.lefttime)
    elseif info.room_state == State.WaitSettle then
        self:call("Niu2View" , "dispatchPoker" , info.lefttime)
    elseif info.room_state == State.Wait then

    end

    if info.chouma ~= 0 then
        self:call("Niu2View" , "onPlayerBet" , free , info.chouma)
    end
end

function M:noticeRobBanker(info)
    self:setGameState(info.room_state)
    self:call("Niu2View" , "onNoticeRobBanker" , info.can_qiangzhuang == 0 , info.lefttime)
end

function M:getGameState()
    return self.__state
end

function M:setGameState(val)
    self.__preState = self.__state
    self.__state = val
end

function M:onPlayerEnterRoom(info)
    self._DB:setComptitorData(info)
    self:closeView("Niu2Settle")
    self:setGameState(info.room_state)
    -- print("+++++++++++++++++++++++" , info.)
    self:call("Niu2View" , "onPlayerAll" , info.lefttime)
end

function M:confirmBanker(info)
    self._DB:setBanker(info.player_id)
    self:setGameState(info.room_state)
    self:call("Niu2View" , "onConfirmBanker" , info.lefttime , info.animation == 1)
end

function M:onDispatchPoker(info)
    self.__state = GameState.Running
    self._DB:setMyCards(info.cards)
    self:setGameState(info.room_state)
    self:call("Niu2View" , "dispatchPoker" , info.lefttime)
end

function M:reqRobBanker(bRob)
    netCom.send({bRob and 0 or 1} , 71004)
end

function M:reqReady(callback)
    local uid = Game.playerDB:getPlayerUid()
    netCom.send({uid} , 71002)
end

function M:respReady(info)
    self._DB:setReady(info.player_id)
    self:call("Niu2View" , "onPlayerReady")
end

function M:reqShow()
    local uid = Game.playerDB:getPlayerUid()
    netCom.send({uid} , 71008)
end

function M:respShow(info)
    self._DB:setPlayerCards(info.player_id , info.cards)
    if self._DB:hasShow(info.player_id) then
        return
    end
    self._DB:playerShow(info.player_id)
    self:call("Niu2View" , "onPlayerShow" , info)
end

function M:getChipValueLst()
    local myCoin = Game.playerDB:getPlayerCoin()
    local cmpCoin = self._DB:getCmpCoin()
    local coin = myCoin < cmpCoin and myCoin or cmpCoin
    local roomId = self._DB:getRoomId()
    local ret = clone(DouniuRoomConfig.quota_proportion(roomId))
    dump(ret)
    print("myCoin , cmpCoin , coin" , myCoin , cmpCoin , coin , roomId)
    for i , val in ipairs(ret) do
        ret[i] = math.floor(val * coin / 10000)
    end
    dump(ret)
    return ret
end

function M:reqBet(coin , callback)
    netCom.send({coin} , 71006)
end

function M:respBet(info)
    self._DB:setBet(info.chouma , info.player_id)
    self:call("Niu2View" , "onPlayerBet" , info.player_id , info.chouma)
end

function M:onResult(info)

    self._DB:setResult(info)

    local banker = self._DB:getBanker()
    self._DB:setCoin(info.lost_player_id , info.lost_coin)
    self._DB:setCoin(info.win_player_id, info.win_coin)

    self._DB:setReady(info.lost_player_id , false)
    self._DB:setReady(info.win_player_id , false)

    if banker == info.win_player_id then
        -- 庄家赢
        self:call("Niu2View" , "moveChipsToSeat" , banker , function(node)
            self:refreshView("Niu2View")
            performWithDelay(node , handler(self , self.showSettleView) , 0.2)
        end)
    else
        -- 闲家赢
        common_util.series({
            function(cb)
                self:call("Niu2View" , "onPlayerBet" , info.lost_player_id , info.lost_chouma , cb,1)
            end,
            function(cb , node)
                performWithDelay(node , cb , 0.3)
            end,
            function(cb)
                self:call("Niu2View" , "moveChipsToSeat" , info.win_player_id , cb)
            end,
            function(cb , node)
                self:refreshView("Niu2View")
                performWithDelay(node , handler(self , self.showSettleView) , 0.3)
            end
        })
    end

    self:respShow({
        player_id = info.win_player_id,
        cards = info.win_cards
    })

    self:respShow({
        player_id = info.lost_player_id,
        cards = info.lost_cards
    })

    -- self:refreshView("Niu2View")

end

function M:reqTrans(callback)
    local uid = Game.playerDB:getPlayerUid()
    netCom.send({uid} , 71012 , function(pack)
        local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_change_table")
        dump(info)
        if info.ret_code == 0 then
            self._DB:reset()
            self:setGameState(State.Idle)
            self._DB:resetRecord()
            self:refreshView()
            self:call("Niu2View" , "breakCountTime")
            execute(callback)
        else
            Game:tipError(info.ret_code , 2)
        end
    end)
end

function M:showSettleView(info)
    local view = require_ex("games.niu2.views.Niu2Settle").new(self , info , handler(self , self.tryClear)):addToScene()

    view.onDestroy = function()
        self._DB:setBanker(nil)
        self._DB:resetMyData()
        self._DB:resetCmpttData()
        self:refreshView("Niu2View")
    end

    -- self:call("Niu2View" , "showWaitTips")
end

function M:reqEnterGame(roomId , callback)
    netCom.send({roomId} , 71000 , function(pack)
        local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_enter")
        dump(info)
        if info.ret_code == 0 then
            self:enterGame(info.room_id)
            execute(callback)
        else
            Game:tipError(info.ret_code , 2 , function()
                Game:openGameWithIdx(SCENCE_ID.PLATEFORM, MoreGameView)
            end)
        end
    end)
    self:registerGameEvent()
end

function M:enterGame(roomId)
    self:setGameState(State.Idle)
    self._DB:reset()
    self._DB:setRoomId(roomId)
    dump(roomId)
    require_ex("games.niu2.views.Niu2View").new(self , roomId):addToScene()
end

function M:reqExitGame(callback)
    local uid = Game.playerDB:getPlayerUid()
    netCom.send({uid} , 71010 , function(pack)
        local info , cursor = netCom.parsePackByProtocol(pack, cursor, "s2c_2niu_quit")
        dump(info)
        execute(callback)
    end)
end

function M:exitGame(info)
    if info.ret_code ~= 0 then
        Game:tipError(info.ret_code , 2)
        return
    end
    self:setGameState(info.room_state)

    local myId = Game.playerDB:getPlayerUid()
    if myId == info.player_id then
        print("self exit")
        if info.reason == 2 then
            require_ex("util.helper.Delayer").new(2 , handler(self , self.onKicked))
        else
            self:unRegisterGameEvent()
            self._DB:resetRecord()
            self:closeView("Niu2View")
        end
    else
        print("other exit")
        local num = self:call("Niu2View" , "getChipsNum")
        if num ~= nil and num > 0 then
            self.__needClear = true
        else
            self:clearData(false)
        end
    end
end

function M:tryClear()
    print("tryClear")
    if self.__needClear then
        self:clearData()
    end
end

function M:clearData(flag)
    print("clearData")
    self._DB:reset(flag)
    self._DB:resetCmpttRecord()
    local myData = self._DB:getMyData()
    local cmpData = self._DB:getComptitorData()
    self:refreshView()
    self:call("Niu2View" , "breakCountTime")
    self.__needClear = false
end

function M:onKicked()
    self:unRegisterGameEvent()
    print("onkicked")
    local roomId = self._DB:getRoomId()
    local cost = DouniuRoomConfig.limit_min_coin(roomId)
    local coin = Game.playerDB:getPlayerCoin()
    print("my coin" , coin)
    print("cost" , cost)
    print(roomId)
    if coin < cost then
        common_util.series({
            function(cb)
                Game:tipMsg("金币不足，请充值" , 0.5 , cb)
            end,
            function(cb)
                Game:openGameWithIdx(SCENCE_ID.PLATEFORM, MoreGameView)
                Game.rechargeCom:checkCoinEnough(cost , 3 , function ()
                    Game:openGameWithIdx(GAMESIDX_TO_SCENCE_ID[6])
                end , function()
                    -- body 空函数
                end , function()
                    -- body 空函数
                end)
            end
        })
    end
    -- Game:openGameWithIdx(GAMESIDX_TO_SCENCE_ID[6])
end

function M:registerGameEvent()
    for key , func in pairs(self._gameCallbacks) do
        netCom.registerCallBack(key , func , true)
    end
end

function M:unRegisterGameEvent()
    for key , func in pairs(self._gameCallbacks) do
        netCom.unRegisterCallBack(key)
    end
end


function M:onEnter()
    local roomId = getCurRoomId()
    print(roomId , "====================================")
    if roomId then
        Game.niu2Com:reqEnterGame(roomId)
        setCurRoomId(nil)
        return
    end
    roomId = 301
    local coin = Game.playerDB:getPlayerCoin()
    local lst = {304 , 303 , 302 , 301}

    local ids = DouniuRoomConfig.getIds()
    local fIds = {}
    for __ , id in ipairs(ids) do
        if DouniuRoomConfig.type(id) == 3 then
            table.insert(fIds , id)
        end
    end

    table.sort(fIds , function(v1 , v2)
        return v1 > v2
    end)
    dump(fIds)
    for __ , id in ipairs(fIds) do
        if coin >= DouniuRoomConfig.limit_min_coin(id) then
            roomId = id
            break
        end
    end
    Game.niu2Com:reqEnterGame(roomId)
end

function M:onExit()
    self.super.onExit(self)
end
return M.new()