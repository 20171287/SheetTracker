import UIKit
import SceneKit
import ARKit
import WebKit
import PDFKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    
    // 40이 차면 이전이나 다음 악보로 넘어가게 해줌
    var cnt_top: Int = 0
    var cnt_bottom: Int = 0
    
    // progress bar
    @IBOutlet weak var top: UIView!
    @IBOutlet weak var bottom: UIView!
    @IBOutlet weak var topProgress: UIProgressView!
    @IBOutlet weak var bottomProgress: UIProgressView!
    
    
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet var faceView: UIView!
    @IBOutlet var leftEyeView: UIView!
    @IBOutlet var rightEyeView: UIView!
    @IBOutlet var leftEyeBallView: UIView!
    @IBOutlet var rightEyeBallView: UIView!
    @IBOutlet weak var eyePositionIndicatorView: UIView!
    @IBOutlet weak var eyeTrackingPositionView: UIView!
    @IBOutlet weak var eyeTargetPositionX: UILabel!
    @IBOutlet weak var eyeTargetPsoitionY: UILabel!
    
    var btnList: [UIButton] = [UIButton]()
    var faceNode: SCNNode = SCNNode()
    
    // pdf 띄울 뷰와 URL
    var pdfView: PDFView = PDFView()
    var pdfURL: PDFDocument?
    
    // 실제 iPad pro 12.9인치 의 물리적 크기 21.49 cm x 28.06cm
    let padScreenSize = CGSize(width: 0.2149, height: 0.2806)
    // 실제 iPhoneX의 Point Size 1194×834 points
    let padScreenPointSize = CGSize(width: 2048/2, height: 2732/2)
    
    // 두 시력이 Hitting 되는 즉 스크린에 시선이 향하는 곳의 위치 좌표를 저장 할 배열
    var eyeLookAtPositionXs: [CGFloat] = []
    var eyeLookAtPositionYs: [CGFloat] = []
    
    var leftEyeNode: SCNNode = {
        // 1. set Geometry "Cone"
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.1)
        /// Cone 주의의 부드러운 곡선의 정도를 설정(기본 = 48, 최소 = 3)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.red
        // 2. SCNNode 생성후 geometry 설정
        let eyeNode = SCNNode()
        eyeNode.geometry = geometry
        eyeNode.eulerAngles.x = -.pi / 2
        // 초기위치
        eyeNode.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(eyeNode)
        return parentNode
    }()
    
    var rightEyeNode: SCNNode = {
        // 1. set Geometry "Cone"
        let geometry = SCNCone(topRadius: 0.005, bottomRadius: 0, height: 0.1)
        /// Cone 주의의 부드러운 곡선의 정도를 설정(기본 = 48, 최소 = 3)
        geometry.radialSegmentCount = 3
        geometry.firstMaterial?.diffuse.contents = UIColor.red
        // 2. SCNNode 생성후 geometry 설정
        let eyeNode = SCNNode()
        eyeNode.geometry = geometry
        eyeNode.eulerAngles.x = -.pi / 2
        // 초기위치
        eyeNode.position.z = 0.1
        let parentNode = SCNNode()
        parentNode.addChildNode(eyeNode)
        return parentNode
    }()
    
    // Phone View에 타겟팅 될 SCNNode
    var targetLeftEyeNode: SCNNode = SCNNode()
    var targetRightEyeNode: SCNNode = SCNNode()
    
    // 각각의 eyeNode가 targeting 될 Pad의 가상 SCNNode
    var virtualPadNode: SCNNode = SCNNode()
    
    // Pad Screen 위의 가상 SCNNode
    var virtualScreenNode: SCNNode = {
        let screenGeometry = SCNPlane(width: 1, height: 1)
        // SceneKit이 표면의 앞면과 뒷면을 렌더링 해야하는지 여부를 결정
        screenGeometry.firstMaterial?.isDoubleSided = true
        screenGeometry.firstMaterial?.diffuse.contents = UIColor.green
        let vsNode = SCNNode()
        vsNode.geometry = screenGeometry
        return vsNode
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        pdfView = PDFView(frame: self.faceView.bounds)
        pdfView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pdfView.usePageViewController(true)
        pdfView.isUserInteractionEnabled = false
        self.faceView.addSubview(pdfView)
        
        pdfView.autoScales = true
        
        if let pdfURL = pdfURL {
            pdfView.document = pdfURL
        }
        
        // Set the button Array
        
        // Set the SceneView's delegate
        sceneView.delegate = self
        sceneView.session.delegate = self
        // 자동으로 SCNLight 생성 여부를 결정
        sceneView.automaticallyUpdatesLighting = true
        
        // Setup SceneGraph (SCNNode 의 순서를 결정)
        /// rootNode -> faceNode -> leftEyeNode -> targetLeftEyeNode
        ///                      -> rightEyeNode -> targetRightEyeNode
        ///          -> virtualPadNode -> virtualScreenNode
        sceneView.scene.rootNode.addChildNode(faceNode)
        sceneView.scene.rootNode.addChildNode(virtualPadNode)
        virtualPadNode.addChildNode(virtualScreenNode)
        faceNode.addChildNode(leftEyeNode)
        faceNode.addChildNode(rightEyeNode)
        leftEyeNode.addChildNode(targetLeftEyeNode)
        rightEyeNode.addChildNode(targetRightEyeNode)
        
        // 안구에서 2미터 떨어진 곳에 타겟팅 설정
        self.targetLeftEyeNode.position.z = 2
        self.targetRightEyeNode.position.z = 2
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Face Tracking을 위한 session Configuration 생성
        guard ARFaceTrackingConfiguration.isSupported else {
            fatalError("이 장치에서는 얼굴 추적 기능이 지원 되지 않습니다.")
        }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        // Run the view's session
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        sceneView.session.pause()
    }
    
}

extension ViewController {
    
    func increaseCnt(_ view: UIProgressView, _ dir: Int) {
            // cnt 값을 프로그래스 바에 반영
            let progress = Float(dir) / 30.0 // cnt 값을 0부터 30까지로 정규화
            view.progress = progress
    }
    
    func navigateToPageAtPoint(_ point: CGPoint, _ dir: Int) {
        guard let document = pdfView.document else { return }
        if let currentPage = pdfView.currentPage {
            let pageIndex = document.index(for: currentPage)
            let nextPageIndex = (pageIndex + dir) % document.pageCount
            pdfView.go(to: document.page(at: nextPageIndex)!)
        }
    }
    
    // 새로운 ARAnchor가 추가 될때마다 호출 되는 함수
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        faceNode.transform = node.transform
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        updateAnchor(withFaceAnchor: faceAnchor)
    }
    
    
    func updateAnchor(withFaceAnchor anchor: ARFaceAnchor) {
        // 양눈의 변환 행렬 반환
        //이 속성의 값을 설정하면 노드의 simdRotation, simdOrientation, simdEulerAngles, simdPosition 및 simdScale 속성이 새 변환과 일치하도록 자동으로 변경
        leftEyeNode.simdTransform = anchor.leftEyeTransform
        rightEyeNode.simdTransform = anchor.rightEyeTransform
        var leftEyeHittingAt = CGPoint()
        var rightEyeHittingAt = CGPoint()
    
        
        let heightCompensation: CGFloat = 312
        
        DispatchQueue.main.async {
            let padScreenEyeRHitTestResults = self.virtualPadNode.hitTestWithSegment(from: self.targetLeftEyeNode.worldPosition, to: self.leftEyeNode.worldPosition, options: nil)
            
            let padScreenEyeLHitTestResults = self.virtualPadNode.hitTestWithSegment(from: self.targetRightEyeNode.worldPosition, to: self.rightEyeNode.worldPosition, options: nil)
            
            for result in padScreenEyeLHitTestResults {
                
                leftEyeHittingAt.x = CGFloat(result.localCoordinates.x) / (self.padScreenSize.width / 2) * self.padScreenPointSize.width
                
                leftEyeHittingAt.y = CGFloat(result.localCoordinates.y) / (self.padScreenSize.height / 2) * self.padScreenPointSize.height + heightCompensation
            }
            
            for result in padScreenEyeRHitTestResults {
                
                rightEyeHittingAt.x = CGFloat(result.localCoordinates.x) / (self.padScreenSize.width / 2) * self.padScreenPointSize.width
                
                rightEyeHittingAt.y = CGFloat(result.localCoordinates.y) / (self.padScreenSize.height / 2) * self.padScreenPointSize.height + heightCompensation
            }
            
            
            self.setUpTargetPosition(left: leftEyeHittingAt, right: rightEyeHittingAt)
            
        }
        
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        guard let sceneTransformInfo = sceneView.pointOfView?.transform else {
            return
        }
        virtualPadNode.transform = sceneTransformInfo
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        faceNode.transform = node.transform
        guard let faceAnchor = anchor as? ARFaceAnchor else {
            return
        }
        updateAnchor(withFaceAnchor: faceAnchor)
        
    }
    
    // Screen 위의 Eye Trarget Position에 따라 eyeTrackingPositionView를 이동한다.
    func setUpTargetPosition(left leftEyeHittingAt: CGPoint, right rightEyeHittingAt: CGPoint)  {
        // X,Y Point 가 유효하게 저장되는 임계점 상수 설정
        let smoothThresHoldNum = 10
        self.eyeLookAtPositionXs.append((rightEyeHittingAt.x + leftEyeHittingAt.x) / 2)
        self.eyeLookAtPositionYs.append(-(rightEyeHittingAt.y + leftEyeHittingAt.y) / 2)
        self.eyeLookAtPositionXs = Array(self.eyeLookAtPositionXs.suffix(smoothThresHoldNum))
        self.eyeLookAtPositionYs = Array(self.eyeLookAtPositionYs.suffix(smoothThresHoldNum))
    
        let smoothEyeLookAtPositionX = self.eyeLookAtPositionXs.eyePositionEverage
        let smoothEyeLookAtPositionY = self.eyeLookAtPositionYs.eyePositionEverage
        
        // update indicator position
        self.eyePositionIndicatorView.transform = CGAffineTransform(translationX: smoothEyeLookAtPositionX!, y: smoothEyeLookAtPositionY!)
        
        let x = Int(round(smoothEyeLookAtPositionX! + self.padScreenPointSize.width / 2))
        let y = Int(round(smoothEyeLookAtPositionY! + self.padScreenPointSize.height / 2))
        
        if  x < 0 { self.eyeTargetPositionX.text = "0" }
        else { self.eyeTargetPositionX.text = "\(x)" }
       
        if y < 0 { self.eyeTargetPsoitionY.text = "0" }
        else { self.eyeTargetPsoitionY.text = "\(y)" }
        
        // 두 눈이 가리키는 좌표
        let point = CGPoint(x: x, y: y)
        
        // UIView 생성 및 속성 설정
        let circleView = UIView(frame: CGRect(x: x, y: y, width: 60, height: 60))
        circleView.backgroundColor = #colorLiteral(red: 0.1658741534, green: 0.502784431, blue: 0.6534992456, alpha: 1)
        circleView.alpha = 1 / 10
        circleView.layer.cornerRadius = circleView.frame.width / 2
        
        // 화면에 추가
        self.view.addSubview(circleView)
        
        // 3초 후에 뷰를 제거하는 타이머 설정
        Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { _ in
            circleView.removeFromSuperview()
        }
        
        increaseCnt(topProgress, cnt_top)
        increaseCnt(bottomProgress, cnt_bottom)
        
        if top.frame.contains(point) {
            cnt_top += 1
            if cnt_top == 40 {
                navigateToPageAtPoint(point, pdfView.document!.pageCount - 1)
                cnt_top = 0
            }
            
        } else if bottom.frame.contains(point) {
            cnt_bottom += 1
            if cnt_bottom == 40 {
                navigateToPageAtPoint(point, pdfView.document!.pageCount + 1)
                cnt_bottom = 0
            }
        } else {
            cnt_top = 0
            cnt_bottom = 0
            return
        }
        
        let ratioValue = view.frame.height / leftEyeView.frame.height
        
        if smoothEyeLookAtPositionX! / ratioValue < leftEyeView.frame.maxX && smoothEyeLookAtPositionY! / ratioValue < leftEyeView.frame.maxY {
             let leftTransform = CGAffineTransform(translationX: smoothEyeLookAtPositionX! / ratioValue , y: smoothEyeLookAtPositionY! / ratioValue)
            self.leftEyeBallView.transform = leftTransform
        }
        
        if smoothEyeLookAtPositionX! / ratioValue < rightEyeView.frame.maxX && smoothEyeLookAtPositionY! / ratioValue < rightEyeView.frame.maxY {
            let leftTransform = CGAffineTransform(translationX: smoothEyeLookAtPositionX! / ratioValue , y: smoothEyeLookAtPositionY! / ratioValue)
            self.rightEyeBallView.transform = leftTransform
        }
    }
}

