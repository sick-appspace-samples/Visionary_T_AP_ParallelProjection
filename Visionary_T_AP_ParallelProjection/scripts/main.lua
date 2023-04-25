--[[----------------------------------------------------------------------------

  Application Name: Visionary_T_AP_ParallelProjection
  
  Summary:
  Sample to show how to get a parallel projection of the scene out of a Depth map image.
  
  Description:
  Set up the camera to take live images continuously and automatically calculate
  pointclouds out of it. First the full depthmap image is shown on the left Viewer. In
  the second viewer to the right, the depthmap image is converted to a pointcloud and shown.
  In the bottom viewer, height map image of the point cloud rotated by a specified angle
  along the Y and X axes is shown.
  
  How to run:
  Start by running the app (F5) or debugging (F7+F10).
  Set a breakpoint on the first row inside the main function to debug step-by-step.
  See the results in the different 3D and 2D viewers on the DevicePage.
  
  More Information:
  If you want to run this app on an emulator some changes are needed to get images.
    
------------------------------------------------------------------------------]]
--Start of Global Scope---------------------------------------------------------
--Log.setLevel("INFO")
-- Variables, constants, serves etc. should be declared here.

-- Setup the camera and get the camera model
local camera = Image.Provider.Camera.create()
Image.Provider.Camera.stop(camera)
-- Get the camera model
local cameraModel = Image.Provider.Camera.getInitialCameraModel(camera)

-- initialize the point cloud converter with the camera model
local pc_converter = Image.PointCloudConversion.RadialDistance.create()
pc_converter:setCameraModel(cameraModel)

-- Setup the viewers
local viewers =
  { View.create("v1"),
    View.create("v2"),
    View.create("v3") }

local deco1 = View.ImageDecoration.create()
deco1:setRange(1150, 2500)
local deco2 = View.ImageDecoration.create()
deco2:setRange(150, 1500)

-- Angles closer to +90 and -90 may result in only a line in the resulting height map
local splatSize = 5
local xRotationAngle = 0
local yRotationAngle = 0

-- Box which form the ROI
local box = nil

-- Transformations for the box
local boxTransform = nil

-- Transformations for rotating the point cloud
local pcTransform_Rotation = nil
--End of Global Scope-----------------------------------------------------------

--Start of Function and Event Scope---------------------------------------------

local function updateTransforms()
  -- Update the Transformation objects according to the new rotation angles
  boxTransform = Transform.createRigidEuler3D("ZYX", 0,
                                            math.rad(yRotationAngle), math.rad(xRotationAngle), 0, 0, 250)
  box = Shape3D.createBox(3000, 2000, 2000, boxTransform)
  pcTransform_Rotation = Transform.createRigidEuler3D("ZYX", math.rad(180),
                                            math.rad(yRotationAngle), math.rad(xRotationAngle), 0, 0, 0)
end

---Bound to UI Element and sets x angle
---@param change int x angle
local function getXAngle(change)
  xRotationAngle = change
  updateTransforms()
end
Script.serveFunction("Visionary_T_AP_ParallelProjection.getXAngle", getXAngle)

---Bound to UI Element and sets y angle
---@param change int y angle
local function getYAngle(change)
  yRotationAngle = change
  updateTransforms()
end
Script.serveFunction("Visionary_T_AP_ParallelProjection.getYAngle", getYAngle)

---Bound to UI Element and sets Splat Size
---@param change int Splat Size
local function setSplatSize(change)
  splatSize = change
end
Script.serveFunction("Visionary_T_AP_ParallelProjection.setSplatSize", setSplatSize)

local function main()
  -- Setup the transformation objects with the default values
  updateTransforms()
  -- Update the camera configuration and start image acquisition
  local config = Image.Provider.Camera.getConfig(camera)
  config:setFramePeriod(33333)
  Image.Provider.Camera.setConfig(camera, config)
  Image.Provider.Camera.start(camera)
end
--The following registration is part of the global scope which runs once after startup
--Registration of the 'main' function to the 'Engine.OnStarted' event
Script.register("Engine.OnStarted", main)

--------------------------------------------------------------------------------
local lasttime = 0
---Callback funtion which is called when a new image is available
---@param image Image[] table which contains all received images
local function handleOnNewImage(image)
  local starttime = DateTime.getTimestamp()
  -- Get the point cloud from the z map image
  local pointCloud = pc_converter:toPointCloud(image[1])
  pointCloud:transformInplace(Transform.createTranslation3D(0, 0, -1000))

  -- Get the height map image (range image) from the point cloud for different directions
  local rangeImage = PointCloud.toImage(pointCloud:transform(pcTransform_Rotation), box, {1, 1, 0.1},
                                                  {splatSize}, "BOTTOMMOST")

  View.clear(viewers[1])
  View.addHeightmap(viewers[1], {image[1]}, deco1)
  View.present(viewers[1])

  View.clear(viewers[2])
  View.addDepthmap(viewers[2], {image[1]}, cameraModel, deco1)
  View.present(viewers[2])

  View.clear(viewers[3])
  View.addHeightmap(viewers[3], {rangeImage}, deco2)
  View.present(viewers[3])
  local endtime = DateTime.getTimestamp()
  Log.info("time betwwen: " .. (starttime - lasttime) .. "ms, processing time: " .. (endtime - starttime) .. " ms" )
  lasttime = starttime
end
--------------------------------------------------------------------------------
-- eventQueueHandle needed to handle the situation that
-- more frames arrives than our script can process
local eventQueueHandle = Script.Queue.create()
eventQueueHandle:setMaxQueueSize(1)
eventQueueHandle:setPriority("HIGH")
eventQueueHandle:setFunction(handleOnNewImage)
Image.Provider.Camera.register(camera, "OnNewImage", handleOnNewImage)
--End of Function and Event Scope-----------------------------------------------
