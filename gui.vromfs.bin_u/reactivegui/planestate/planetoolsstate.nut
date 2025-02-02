let interopGen = require("%rGui/interopGen.nut")

let IlsVisible = Watched(false)
let IlsPosSize = [0, 0, 0, 0]
let IlsColor = Watched(Color(255, 255, 0, 240))
let IlsLineScale = Watched(1.0)
let BombingMode = Watched(false)
let AimLocked = Watched(false)
let TargetPosValid = Watched(false)
let TargetPos = Watched([0, 0])
let TimeBeforeBombRelease = Watched(0.0)
let DistToSafety = Watched(0.0)
let DistToTarget = Watched(0.0)
let RocketMode = Watched(false)
let CannonMode = Watched(false)
let BombCCIPMode = Watched(false)
let BlkFileName = Watched("")
let IsMfdEnabled = Watched(false)
let MfdOpticAtgmSightVis = Watched(false)
let MfdSightPosSize = [0, 0, 0, 0]
let IlsAtgmTrackerVisible = Watched(false)
let IlsAtgmTargetPos = [0, 0]
let IlsAtgmLocked = Watched(false)
let RwrScale = Watched(1.0)
let RadarTargetDist = Watched(0.0)
let RadarTargetPosValid = Watched(false)
let RadarTargetPos = [0, 0]
let AamAccelLock = Watched(false)
let MfdRadarWithNavVis = Watched(false)
let MfdRadarNavPosSize = [0, 0, 0, 0]
let AimLockPos = [0, 0]
let AimLockValid = Watched(false)
let TvvMark = [0, 0]
let AtgmTargetDist = Watched(0.0)

let planeState = {
  BlkFileName,
  IlsVisible,
  IlsPosSize,
  IlsColor,
  IlsLineScale,
  BombingMode,
  AimLocked,
  TargetPosValid,
  TargetPos,
  TimeBeforeBombRelease,
  DistToSafety,
  DistToTarget,
  RocketMode,
  CannonMode,
  BombCCIPMode,
  IsMfdEnabled,
  MfdOpticAtgmSightVis,
  MfdSightPosSize,
  IlsAtgmTrackerVisible,
  IlsAtgmTargetPos,
  IlsAtgmLocked,
  RwrScale,
  RadarTargetDist,
  RadarTargetPosValid,
  RadarTargetPos,
  AamAccelLock,
  MfdRadarWithNavVis,
  MfdRadarNavPosSize,
  AimLockValid,
  AimLockPos,
  TvvMark,
  AtgmTargetDist
}

::interop.updatePlaneIlsPosSize <- function(x, y, w, h) {
  IlsPosSize[0] = x
  IlsPosSize[1] = y
  IlsPosSize[2] = w
  IlsPosSize[3] = h
}

::interop.updatePlaneMfdSightPosSize <- function(x, y, w, h) {
  MfdSightPosSize[0] = x
  MfdSightPosSize[1] = y
  MfdSightPosSize[2] = w
  MfdSightPosSize[3] = h
}

::interop.updatePlaneMfdRadarNavPosSize <- function(x, y, w, h) {
  MfdRadarNavPosSize[0] = x
  MfdRadarNavPosSize[1] = y
  MfdRadarNavPosSize[2] = w
  MfdRadarNavPosSize[3] = h
}

::interop.updateAimLockPos <- function(x, y) {
  AimLockPos[0] = x
  AimLockPos[1] = y
}

::interop.updateRadarTargetPos <- function(x, y) {
  RadarTargetPos[0] = x
  RadarTargetPos[1] = y
}

::interop.updateIlsAtgmTargetPos <- function(x, y) {
  IlsAtgmTargetPos[0] = x
  IlsAtgmTargetPos[1] = y
}

::interop.updateTvvTarget <- function(x, y) {
  TvvMark[0] = x
  TvvMark[1] = y
}

interopGen({
  stateTable = planeState
  prefix = "plane"
  postfix = "Update"
})

return planeState