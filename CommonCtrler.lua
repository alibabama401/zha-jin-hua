-- @Author: ZhuL
-- @Date:   2017-05-17 15:51:12
-- @Last Modified by:   ZhuL
-- @Last Modified time: 2017-05-19 16:15:23

--[[
通用控制器
提供消息接收发送界面以及功能
提供通用title接口
]]

local BaseCom = require_ex("data.BaseCom")
local M = class("CommonCtrler" , BaseCom)

function M:ctor()
    BaseCom.ctor(self)

    self._msgQueue = require("lib.Queue").new()
end

------------------------------ 聊天 start ----------------------------

function M:registerChatEvent()
    -- body
end

function M:unRegisterChatEvent()
    -- body
end

function M:onReceiveMsg(msgType , data)
    local chatView = self._viewMap["ChatView"]
    if not chatView then
        return
    end
    self:pushMsg({type = msgType , data = data})
    chatView:tryToShowMsg()
end

function M:getMsgCount()
    return self._msgQueue:length()
end

function M:pushMsg(msg)
    self._msgQueue:push(msg)
end

function M:popMsg()
    return self._msgQueue:pop()
end

function M:addChatView(parent)
    local chatView = require_ex("games.niuniu.views.ChatView").new(self)
    parent:addChatView(chatView)
end

function M:reqSendEmoji(emojiLst)
    -- body
    self:onReceiveMsg(1 , emojiLst)
end

function M:reqSendMsg(msg)
    -- body
    self:onReceiveMsg(2 , msg)
end

------------------------------ 聊天 end ----------------------------

return M.new()