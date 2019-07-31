//
//  ViewController.swift
//  vindiIOS
//
//  Created by Jonna Karlsson Sellén on 2019-07-23.
//  Copyright © 2019 Jonna Karlsson Sellén. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet weak var sceneView: ARSCNView!
    var planeGeometry:SCNPlane!
    var anchors = [ARAnchor]()
    var currentAngleY: Float = 0.0
    var startPosition: SCNNode!
    var trail: Array<obsticalPosition> = []
    var addedStartPos: Bool = false
    
    var isRotating: Bool = false
    
    let configuration = ARWorldTrackingConfiguration()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
        sceneView.delegate = self
        
        trail = [obsticalPosition(angle: 80, dist: 6, type: "cone"),
                obsticalPosition(angle: 90, dist: 11, type: "cone"),
                obsticalPosition(angle: 20, dist: 4, type: "cone"),
                obsticalPosition(angle: -20, dist: 4, type: "cone")]
    }

    @IBAction func add(_ sender: Any) {
        for position in trail {
            let node = SCNNode()
            let pointer = SCNNode()
            
            node.geometry = SCNCylinder(radius: 0.03, height: 0.01)
            pointer.geometry = SCNCone(topRadius: 0.5, bottomRadius: 0, height: 0.5)
            
            node.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            pointer.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
            
            let startPosDegree = rad2deg(startPosition.eulerAngles.y)
            let angle = startPosDegree + position.angle
            let Z = cos(deg2rad(angle)) * position.dist; // x
            let X = sin(deg2rad(angle)) * position.dist; // y

            node.position = SCNVector3(startPosition.position.x + X, startPosition.position.y, startPosition.position.z + Z);
            pointer.position = SCNVector3(startPosition.position.x + X, startPosition.position.y + 1, startPosition.position.z + Z);

            self.sceneView.scene.rootNode.addChildNode(node)
            self.sceneView.scene.rootNode.addChildNode(pointer)
        }
        self.view.gestureRecognizers?.removeAll()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if !addedStartPos {
            let touch = touches.first
            let location = touch?.location(in: sceneView)
            addStartNodeAtLocation(location: location!)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        let node = SCNNode()
        if !addedStartPos {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                planeGeometry = SCNPlane(width: CGFloat(planeAnchor.extent.x), height: CGFloat(planeAnchor.extent.z))
                planeGeometry.firstMaterial?.diffuse.contents = UIColor.white.withAlphaComponent(0.5)
                let planeNode = SCNNode(geometry: planeGeometry)
                planeNode.position = SCNVector3(x: planeAnchor.center.x, y:0, z: planeAnchor.center.z)
                planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
                
                node.name = "plane"
                node.addChildNode(planeNode)
                anchors.append(planeAnchor)
            }
        }
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        if !addedStartPos {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                if anchors.contains(planeAnchor) {
                    if node.childNodes.count > 0 {
                        let planeNode = node.childNodes.first!
                        planeNode.position = SCNVector3(x: planeAnchor.center.x, y:0, z: planeAnchor.center.z)
                        if let plane = planeNode.geometry as? SCNPlane {
                            plane.width = CGFloat(planeAnchor.extent.x)
                            plane.height = CGFloat(planeAnchor.extent.z)
                        }
                    }
                }
            }
        }
    }
    
    func addStartNodeAtLocation(location:CGPoint) {
        guard anchors.count > 0 else {print("Anchors are not created yet"); return}
        
        let hitResults = sceneView.hitTest(location, types: .existingPlaneUsingExtent)
        if hitResults.count > 0 {
            let result = hitResults.first!
            let newLocation = SCNVector3(x: result.worldTransform.columns.3.x, y: result.worldTransform.columns.3.y, z: result.worldTransform.columns.3.z)
            startPosition = SCNNode()
            startPosition.geometry = SCNPlane(width: 0.21, height: 0.297)
            startPosition.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
            startPosition.geometry?.firstMaterial?.diffuse.contents = "Kaktus2.png"
            startPosition.position = newLocation
            self.sceneView.scene.rootNode.addChildNode(startPosition)
            
            addedStartPos = true
            removePlane()
            setGestures()
            
        }
    }
    
    func removePlane() {
        sceneView.scene.rootNode.childNodes.filter({ $0.name == "plane" }).forEach({$0.removeFromParentNode()})
    }
    
    func setGestures() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(moveNode(_:)))
        self.view.addGestureRecognizer(panGesture)

        let rotateGesture = UIRotationGestureRecognizer(target: self, action: #selector(rotateNode(_:)))
        self.view.addGestureRecognizer(rotateGesture)
    }
    
    @objc func rotateNode(_ gesture: UIRotationGestureRecognizer){
        let rotation = Float(gesture.rotation)
        if gesture.state == .changed{
            isRotating = true
            startPosition.eulerAngles.y = currentAngleY + rotation
        }
        if(gesture.state == .ended) {
            currentAngleY = startPosition.eulerAngles.y
            isRotating = false
        }
    }
    
    @objc func moveNode(_ gesture: UIPanGestureRecognizer) {
        if !isRotating{
        let currentTouchPoint = gesture.location(in: self.sceneView)
        guard let hitTest = self.sceneView.hitTest(currentTouchPoint, types: .existingPlane).first else { return }
        let worldTransform = hitTest.worldTransform
        let newPosition = SCNVector3(worldTransform.columns.3.x, worldTransform.columns.3.y, worldTransform.columns.3.z)
        startPosition.simdPosition = SIMD3(newPosition.x, newPosition.y, newPosition.z)
        }
    }
    
    func rad2deg(_ number: Float) -> Float {
        return number * 180 / .pi
    }
    
    func deg2rad(_ number: Float) -> Float {
        return number * .pi / 180
    }
}

struct obsticalPosition {
    var angle: Float = 0
    var dist: Float = 0
    var type: String = ""
}

