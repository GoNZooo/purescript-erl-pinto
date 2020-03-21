-- | Module roughly representing interactions with the 'gen_server'
-- | See also 'gen_server' in the OTP docs
module Pinto.Gen ( startLink
                 , startLinkWithoutName
                 , CallResult(..)
                 , CastResult(..)
                 , call
                 , doCall
                 , doCallByPid
                 , cast
                 , doCast
                 , doCastByPid
                 , defaultHandleInfo
                 , registerExternalMapping
                 , monitorName
                 , monitorPid
                 )
  where

import Prelude

import Data.Either (Either(..))
import Data.Maybe (Maybe)
import Effect (Effect)
import Erl.Atom (atom)
import Erl.Data.Tuple (tuple2, tuple3)
import Erl.ModuleName (NativeModuleName(..))
import Erl.Process.Raw (Pid)
import Foreign (Foreign, unsafeToForeign)
import Pinto (ServerName(..), StartLinkResult)
import Pinto.Types (ServerPid(..))

foreign import callImpl :: forall response state name. name -> (state -> (CallResult response state)) -> Effect response
foreign import doCallImpl :: forall response state name. name -> (state -> Effect (CallResult response state)) -> Effect response
foreign import castImpl :: forall state name. name -> (state -> (CastResult state)) -> Effect Unit
foreign import doCastImpl :: forall state name. name -> (state -> Effect (CastResult state)) -> Effect Unit
foreign import startLinkImpl :: forall a b name state msg. (a -> Either a b) -> (b -> Either a b) ->name -> Effect state -> (msg -> state -> Effect (CastResult state)) -> Effect StartLinkResult
foreign import startLinkImplWithoutName :: forall a b state msg. (a -> Either a b) -> (b -> Either a b) -> Effect state -> (msg -> state -> Effect (CastResult state)) -> Effect StartLinkResult
foreign import registerExternalMappingImpl :: forall externalMsg msg name. name -> (externalMsg -> Maybe msg) -> Effect Unit
foreign import monitorImpl :: forall externalMsg msg name toMonitor. name -> toMonitor -> (externalMsg -> msg) -> Effect Unit

-- These imports are just so we don't get warnings
foreign import code_change :: forall a. a -> a -> a -> a
foreign import handle_call :: forall a. a -> a -> a -> a
foreign import handle_cast :: forall a. a -> a -> a -> a
foreign import handle_info :: forall a. a -> a -> a
foreign import init :: forall a. a -> a
foreign import terminate :: forall a. a -> a -> a
foreign import start_from_spec :: forall a. a -> a

nativeName :: forall state msg. ServerName state msg -> Foreign
nativeName (Local name) = unsafeToForeign $ name
nativeName (Global name) = unsafeToForeign $ tuple2 (atom "global") name
nativeName (Via (NativeModuleName m) name) = unsafeToForeign $ tuple3 (atom "via") m name


-- | Adds a (presumably) native Erlang function into the gen server to map external messages into types that this
-- | gen server actually understands
registerExternalMapping :: forall state externalMsg msg. ServerName state msg -> (externalMsg -> Maybe msg) -> Effect Unit
registerExternalMapping name = registerExternalMappingImpl (nativeName name)

-- | Adds a monitor
monitorName :: forall state name otherState otherName externalMsg msg. ServerName state msg -> ServerName otherState otherName -> (externalMsg -> msg) -> Effect Unit
monitorName name = monitorImpl (nativeName name)

monitorPid :: forall state name externalMsg msg. ServerName state msg -> Pid -> (externalMsg -> msg) -> Effect Unit
monitorPid name = monitorImpl (nativeName name)


-- | Starts a typed gen-server proxy with the supplied ServerName, with the state being the result of the supplied effect
-- |
-- | ```purescript
-- | serverName :: ServerName State Unit
-- | serverName = ServerName "some_uuid"
-- |
-- | startLink :: Effect StartLinkResult
-- | startLink = Gen.startLink serverName init defaultHandleInfo
-- |
-- | init :: Effect State
-- | init = pure {}
-- | ```
-- | See also: gen_server:start_link in the OTP docs (roughly)
startLink :: forall state msg. ServerName state msg -> Effect state -> (msg -> state -> Effect (CastResult state)) -> Effect StartLinkResult
startLink (Local name) = startLink_ $ tuple2 (atom "local") name
startLink (Global name) = startLink_ $ tuple2 (atom "global") name
startLink (Via (NativeModuleName m) name) = startLink_ $ tuple3 (atom "via") m name

startLinkWithoutName :: forall state msg. Effect state -> (msg -> state -> Effect (CastResult state)) -> Effect StartLinkResult
startLinkWithoutName = startLinkImplWithoutName Left Right

startLink_ = startLinkImpl Left Right

data CallResult response state = CallReply response state | CallReplyHibernate response state | CallStop response state
data CastResult state = CastNoReply state | CastNoReplyHibernate state | CastStop state


-- | A default implementation of handleInfo that just ignores any messages received
defaultHandleInfo :: forall state msg. msg -> state -> Effect (CastResult state)
defaultHandleInfo msg state = pure $ CastNoReply state

-- | Defines a "pure" "call" that performs an interaction on the state held by the gen server, but with no other side effects
-- | Directly returns the result of the callback provided
-- | ```purescript
-- |
-- | doSomething :: Effect Unit
-- | doSomething = Gen.call serverName \state -> CallReply unit (modifyState state)
-- | ```
-- | See also handle_call and gen_server:call in the OTP docs
call :: forall response state msg. ServerName state msg -> (state -> (CallResult response state)) -> Effect response
call name fn = callImpl (nativeName name) fn

-- | Defines an effectful call that performs an interaction on the state held by the gen server, and perhaps side-effects
-- | Directly returns the result of the callback provided
-- | ```purescript
-- |
-- | doSomething :: Effect Unit
-- | doSomething = Gen.doCall serverName \state -> pure $ CallReply unit (modifyState state)
-- | ```
-- | See also handle_call and gen_server:call in the OTP docs
doCall :: forall response state msg. ServerName state msg -> (state -> Effect (CallResult response state)) -> Effect response
doCall name fn = doCallImpl (nativeName name) fn

doCallByPid :: ∀ response state. ServerPid state -> (state -> Effect (CallResult response state)) -> Effect response
doCallByPid (ServerPid pid) fn = doCallImpl pid fn

-- | Defines an "pure" cast that performs an interaction on the state held by the gen server
-- | ```purescript
-- | doSomething :: Effect Unit
-- | doSomething = Gen.cast serverName \state -> CastNoReply $ modifyState state
-- | ```
-- | See also handle_cast and gen_server:cast in the OTP docs
cast :: forall state msg. ServerName state msg -> (state -> (CastResult state)) -> Effect Unit
cast name fn = castImpl (nativeName name) fn

-- | Defines an effectful cast that performs an interaction on the state held by the gen server
-- | ```purescript
-- | doSomething :: Effect Unit
-- | doSomething = Gen.cast serverName \state -> pure $ CastNoReply $ modifyState state
-- | ```
-- | See also handle_cast and gen_server:cast in the OTP docs
doCast :: forall state msg. ServerName state msg -> (state -> Effect (CastResult state)) -> Effect Unit
doCast name fn = doCastImpl (nativeName name) fn

doCastByPid :: ∀ state. ServerPid state -> (state -> Effect (CastResult state)) -> Effect Unit
doCastByPid (ServerPid pid) fn = doCastImpl pid fn
