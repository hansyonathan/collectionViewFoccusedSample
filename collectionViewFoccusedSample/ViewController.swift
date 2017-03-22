//
//  ViewController.swift
//  collectionViewFoccusedSample
//
//  Created by Hans Yonathan on 22/3/2017.
//  Copyright © 2017 Hans Yonathan. All rights reserved.
//

import UIKit
import AVFoundation
import MaterialControls
import DZNEmptyDataSet
import SDWebImage

let baseUrl = "https://goldwordsapp.com"
let dbName = "GoldWordsProd"

extension UIView {
    func addConstraint(format: String, views: UIView...){
        var viewsDict = [String: UIView]()
        for(index, view) in views.enumerated() {
            let key = "v\(index)"
            view.translatesAutoresizingMaskIntoConstraints = false
            viewsDict[key] = view
        }
        
        addConstraints(NSLayoutConstraint.constraints(withVisualFormat: format, options: NSLayoutFormatOptions(), metrics: nil, views: viewsDict))
    }
}

protocol PostControllerDelegate {
}

class PostController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    let requestListCellId = "requestListCellId"
    
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.delegate = self
        cv.dataSource = self
        return cv
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        // Do any additional setup after loading the view, typically from a nib.
        view.addSubview(collectionView)
        view.addConstraint(format: "H:|[v0]|", views: collectionView)
        view.addConstraint(format: "V:|[v0]|", views: collectionView)
        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.scrollDirection = .horizontal
            flowLayout.minimumLineSpacing = 0
        }
        collectionView.register(RequestListCell.self, forCellWithReuseIdentifier: requestListCellId)
        collectionView.isPagingEnabled = true
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let identifier:String
        identifier = requestListCellId
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: identifier, for: indexPath) as! RequestListCell
        cell.postController = self
        //cell.delegate = self
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: view.frame.width, height: view.frame.height)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

class RequestListCell: WordListBaseCell {
    
    var requestList: [Words]?
    var wordRequestCardTemp: [RequestBaseCell] = []
    
    override func fetchWords() {
        ApiService.sharedInstance.fetchRequestWordsList(offset: 0) { (requestList: [Words]) in
            self.requestList = requestList
            self.collectionView.reloadData()
            self.clearControlContainerView()
        }
    }
    
    override func setupViews() {
        super.setupViews()
        collectionView.register(RequestCell.self, forCellWithReuseIdentifier: cellId)
    }
    
    override func filterContentForSearchText(_ searchText: String) {
        ApiService.sharedInstance.fetchRequestWordsList(searchString: searchText, offset: 0) { (requestList: [Words]) in
            self.requestList = requestList
            self.collectionView.reloadData()
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! RequestCell
        cell.requestWordCard.requestList = requestList?[indexPath.item]
        cell.requestListCell = self
        cell.requestWordCard.audioPlayer = nil
        return cell
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return requestList?.count ?? 0
    }
    
    override func loadMore() {
        super.loadMore()
        // query the db on a background thread
        DispatchQueue.global(qos: .background).async {
            
            // determine the range of data items to fetch
            var thisBatchOfItems: [Words]?
            let start = self.requestList?.count ?? 0
            // let end = self.offset + self.itemsPerBatch
            
            ApiService.sharedInstance.fetchRequestWordsList(offset: start) { (requestList: [Words]) in
                thisBatchOfItems = requestList
                DispatchQueue.main.async {
                    
                    if let newItems = thisBatchOfItems {
                        
                        // append the new items to the data source for the table view
                        self.requestList?.append(contentsOf: newItems)
                        
                        // reload the table view
                        self.collectionView.reloadData()
                        
                        // check if this was the last of the data
                        if newItems.count < self.itemsPerBatch {
                            self.reachedEndOfItems = true
                            print("reached end of data. Batch count: \(newItems.count)")
                        }
                        
                        // reset the offset for the next data query
                        self.offset += self.itemsPerBatch
                    }
                }
            }
            
            // update UITableView with new batch of items on main thread after query finishes
            
        }
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        return NSAttributedString(string: NSLocalizedString("No Vent from other people ready yet", comment:"for requestlistcell"), attributes:nil
        )
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView!) -> NSAttributedString! {
        return NSAttributedString(string: NSLocalizedString("On here you can hear other people feeling..", comment:"for requestlistcell"), attributes:
            [
                NSFontAttributeName : UIFont.systemFont(ofSize: 17),
                //NSForegroundColorAttributeName : UIColor(red: 218/255, green: 165/255, blue: 32/255, alpha: 1),
            ]
        )
    }
    
    func emptyDataSetShouldAllowScroll(_ scrollView: UIScrollView!) -> Bool {
        return true
    }
    
}

class WordListBaseCell: BaseCell, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UISearchBarDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate {
    
    // number of items to be fetched each time (i.e., database LIMIT)
    let itemsPerBatch = 7
    
    // Where to start fetching items (database OFFSET)
    var offset = 0
    
    // a flag for when all database items have already been loaded
    var reachedEndOfItems = false
    
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.dataSource = self
        cv.delegate = self
        cv.emptyDataSetSource = self
        cv.emptyDataSetDelegate = self
        return cv
    }()
    
    let cellId = "cellId"
    
    var searchBarActive:Bool = false
    
    lazy var refreshControl: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return refreshControl
    }()
    
    lazy var searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.searchBarStyle = .minimal
        sb.placeholder = NSLocalizedString("Search..", comment:"for wordlistbasecell")
        sb.delegate = self
        return sb
    }()
    
    func handleRefresh(){
        cancelSearching()
        let delayTime = DispatchTime.now() + Double(Int64(1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        reachedEndOfItems = false
        DispatchQueue.main.asyncAfter(deadline: delayTime) {
            self.fetchWords()
            self.refreshControl.endRefreshing()
        }
    }
    
    func fetchWords(){
        
    }
    
    override func setupViews() {
        super.setupViews()
        //        setupControlContainerView()
        //        UIView.animate(withDuration: 0.5, animations: {
        //            self.self.fetchWords()
        //        }) { (completed) in
        //            self.clearControlContainerView()
        //        }
        
        if #available(iOS 10.0, *) {
            collectionView.refreshControl = refreshControl
        } else {
            // Fallback on earlier versions
        }
        addSubview(searchBar)
        addSubview(collectionView)
        collectionView.addSubview(refreshControl)
        collectionView.alwaysBounceVertical = true
        addConstraint(format: "H:|[v0]|", views: searchBar)
        addConstraint(format: "H:|[v0]|", views: collectionView)
        addConstraint(format: "V:|[v0][v1]|", views: searchBar, collectionView)
        collectionView.register(WordCell.self, forCellWithReuseIdentifier: cellId)
        collectionView.scrollIndicatorInsets = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        collectionView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 50, right: 0)
        setupControlContainerView()
        DispatchQueue.main.async {
            self.fetchWords()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 5
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: frame.width, height: 200)
    }
    
    /*func scrollViewDidScroll(_ scrollView: UIScrollView) {
     let threshold = 100.0 as CGFloat!
     let contentOffset = scrollView.contentOffset.y
     let maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height;
     if (Float(maximumOffset - contentOffset) <= Float(threshold!)) && (maximumOffset - contentOffset != -5.0) {
     loadMore()
     }
     }*/
    
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        //  only moves in one direction, y axis
        let currentOffset = scrollView.contentOffset.y
        let maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height
        
        // Change 10.0 to adjust the distance from bottom
        //print("currentofset", currentOffset)
        //print("max", maximumOffset)
        if maximumOffset - currentOffset <= 10.0 {
            //print("load more")
            loadMore()
        }
    }
    
    func loadMore() {
        
        // don't bother doing another db query if already have everything
        guard !self.reachedEndOfItems else {
            return
        }
    }
    
    // MARK: Search
    func filterContentForSearchText(_ searchText:String){
        //query for search
        //requestList = [Words()]
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterContentForSearchText(searchText)
        collectionView.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        cancelSearching()
        collectionView.reloadData()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBarActive = true
        endEditing(true)
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        // we used here to set self.searchBarActive = YES
        // but we'll not do that any more... it made problems
        // it's better to set self.searchBarActive = YES when user typed something
        searchBar.setShowsCancelButton(true, animated: true)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        // this method is being called when search btn in the keyboard tapped
        // we set searchBarActive = NO
        // but no need to reloadCollectionView
        searchBarActive = false
        searchBar.setShowsCancelButton(false, animated: false)
    }
    
    func cancelSearching(){
        searchBarActive = false
        searchBar.resignFirstResponder()
        searchBar.text = ""
    }
    
    
}

class BaseCell: UICollectionViewCell {
    
    let activityIndicatorView: UIActivityIndicatorView = {
        let aiv = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        aiv.translatesAutoresizingMaskIntoConstraints = false
        aiv.startAnimating()
        return aiv
    }()
    
    var controlContainerView: UIView?
    
    override init(frame: CGRect){
        super.init(frame: frame)
        setupViews()
    }
    
    func setupViews(){
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented!")
    }
    
    var postController: PostController?
    var delegate: PostControllerDelegate?
    
    
    func setupControlContainerView(){
        if let keyWindow = UIApplication.shared.keyWindow{
            controlContainerView = UIView()
            controlContainerView?.backgroundColor = UIColor(white: 0, alpha: 0.5)
            controlContainerView?.frame = keyWindow.frame
            keyWindow.addSubview(controlContainerView!)
            controlContainerView?.addSubview(activityIndicatorView)
            if #available(iOS 9.0, *) {
                activityIndicatorView.centerXAnchor.constraint(equalTo: controlContainerView!.centerXAnchor).isActive = true
                activityIndicatorView.centerYAnchor.constraint(equalTo: controlContainerView!.centerYAnchor).isActive = true
            } else {
                // Fallback on earlier versions
            }
            activityIndicatorView.startAnimating()
        }
    }
    
    func clearControlContainerView(){
        controlContainerView?.backgroundColor = .clear
        activityIndicatorView.stopAnimating()
        controlContainerView?.removeFromSuperview()
    }
    
}

class SaveJsonObject: NSObject {
    
    override func setValue(_ value: Any?, forKey key: String) {
        let upperCasedFirstCharacter = String(key.characters.first!).uppercased()
        let range = key.startIndex..<key.characters.index(key.startIndex, offsetBy: 1)
        let selectorString = key.replacingCharacters(in: range, with: upperCasedFirstCharacter)
        //print(selectorString)
        let selector = NSSelectorFromString("set\(selectorString):")
        let responds = self.responds(to: selector)
        
        if !responds {
            print("selector:\(selector)")
            return
        }
        //print("\(value), \(key)")
        super.setValue(value, forKey: key)
    }
    
}

class WordsOwnList: SaveJsonObject {
    
    var id: NSNumber?
    var create_uid: ResUser?
    var user_id: ResUser?
    var gw_words_id: Words?
    var sequence: NSNumber?
    var is_goldwords: NSNumber?
    var active: NSNumber?
    var note: String?
    var answer_from_gw_words_id: Words?
    
    override func setValue(_ value: Any?, forKey key: String) {
        if key == "create_uid" {
            self.create_uid = ResUser(dictionary: [:])
            self.create_uid?.setValuesForKeys(value as! [String: AnyObject])
        }
        else if key == "user_id" {
            self.user_id = ResUser(dictionary: [:])
            self.user_id?.setValuesForKeys(value as! [String: AnyObject])
        }
        else if key == "gw_words_id" {
            self.gw_words_id = Words(dictionary: [:])
            self.gw_words_id?.setValuesForKeys(value as! [String: AnyObject])
        }
        else if key == "answer_from_gw_words_id" {
            if (value != nil) {
                self.answer_from_gw_words_id = Words(dictionary: [:])
                self.answer_from_gw_words_id?.setValuesForKeys(value as! [String: AnyObject])
            }
        }
        else {
            super.setValue(value, forKey: key)
        }
    }
    
    init(dictionary: [String: AnyObject]) {
        super.init()
        setValuesForKeys(dictionary)
    }
    
}

class ResUser: SaveJsonObject {
    
    var id: NSNumber?
    var name: String?
    var login: String?
    var profile_image: String?
    var profile_image_small: String?
    var profile_image_medium: String?
    var bou_is_verified: NSNumber?
    var bou_fcm_token: String?
    var bou_badges: NSNumber?
    
    init(dictionary: [String: AnyObject]) {
        super.init()
        setValuesForKeys(dictionary)
    }
    
}

class Words: SaveJsonObject {
    
    var id: NSNumber?
    var create_uid: ResUser?
    var type: String?
    var name: String?
    var file: String?
    var active: NSNumber?
    var length: NSNumber?
    var title: String?
    var filename: String?
    
    override func setValue(_ value: Any?, forKey key: String) {
        if key == "create_uid" {
            self.create_uid = ResUser(dictionary: [:])
            self.create_uid?.setValuesForKeys(value as! [String: AnyObject])
        }
        else {
            super.setValue(value, forKey: key)
        }
    }
    
    init(dictionary: [String: AnyObject]) {
        super.init()
        setValuesForKeys(dictionary)
    }
    
}

class OAuth: SaveJsonObject {
    
    var id: NSNumber?
    var oauth_provider_id: String?
    var oauth_uid: String?
    var oauth_access_token: String?
    var oauth_token_secret: String?
    var username: String?
    var publish_actions: NSNumber?
    
    init(dictionary: [String: AnyObject]) {
        super.init()
        setValuesForKeys(dictionary)
    }
}

class GWNotification: SaveJsonObject {
    
    var id: NSNumber?
    var user_id: ResUser?
    var type: String?
    var words_id: Words?
    var own_list_id: WordsOwnList?
    var sender_id: ResUser?
    var is_read: NSNumber?
    var create_date: String?
    
    override func setValue(_ value: Any?, forKey key: String) {
        if key == "user_id" {
            self.user_id = ResUser(dictionary: [:])
            self.user_id?.setValuesForKeys(value as! [String: AnyObject])
        } else if key == "words_id" {
            self.words_id = Words(dictionary: [:])
            self.words_id?.setValuesForKeys(value as! [String: AnyObject])
        } else if key == "own_list_id" {
            self.own_list_id = WordsOwnList(dictionary: [:])
            self.own_list_id?.setValuesForKeys(value as! [String: AnyObject])
        } else if key == "sender_id" {
            self.sender_id = ResUser(dictionary: [:])
            self.sender_id?.setValuesForKeys(value as! [String: AnyObject])
        }
        else {
            super.setValue(value, forKey: key)
        }
    }
    
    init(dictionary: [String: AnyObject]) {
        super.init()
        setValuesForKeys(dictionary)
    }
}
class WordCard: UIView, AVAudioPlayerDelegate {
    
    var audioPlayer:AVAudioPlayer? = nil
    var isPlaying = false
    var updater : CADisplayLink!
    var urlAudio: URL?
    
    override init(frame: CGRect){
        super.init(frame: frame)
        setupViews()
    }
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Got From Random GoldWords", comment: "for wordcard")
        label.textColor = UIColor(red: 218/255, green: 165/255, blue: 32/255, alpha: 1)
        label.font = .boldSystemFont(ofSize: 16)
        return label
    }()
    
    let userProfileImageView: CachedImageView = {
        let imageView = CachedImageView()
        //imageView.backgroundColor = .blue
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = 22
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.image = UIImage(named: "Circled User Male Filled-100")
        return imageView
    }()
    
    let userNameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "Username"
        label.textColor = .black
        label.font = .boldSystemFont(ofSize: 12)
        //label.backgroundColor = .green
        return label
    }()
    
    let recordIdLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "#ID"
        label.textColor = .black
        label.font = .boldSystemFont(ofSize: 12)
        label.isHidden = true
        return label
    }()
    
    let currentTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "00:00"
        label.textColor = .black
        label.font = .boldSystemFont(ofSize: 12)
        return label
    }()
    
    lazy var audioSlider : UISlider = {
        let slider = UISlider()
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.minimumTrackTintColor = UIColor(red: 218/255, green: 165/255, blue: 32/255, alpha: 1)
        slider.maximumTrackTintColor = .lightGray
        //to set the thumb of the slider
        //slider.setThumbImage(UIImage(named:"circle-16"), for: .normal)
        //slider.thumbRect(forBounds: CGRect, trackRect: <#T##CGRect#>, value: <#T##Float#>)
        //slider.thum
        slider.thumbTintColor = UIColor(red: 218/255, green: 165/255, blue: 32/255, alpha: 1)
        //slider.addTarget(self, action: #selector(handleSliderChange), for: .valueChanged)
        slider.maximumValue = 17 // to test
        slider.addTarget(self, action: #selector(handleSliderSlide), for: .valueChanged)
        slider.isUserInteractionEnabled = false
        return slider
    }()
    
    lazy var pausePlayButton: UIButton = {
        let button = UIButton(type: .system)
        let playImage = UIImage(named: "Circled Play Filled-100")
        button.setImage(playImage, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = UIColor(red: 218/255, green: 165/255, blue: 32/255, alpha: 1)
        button.addTarget(self, action: #selector(handlePlayPause), for: .touchUpInside)
        button.showsTouchWhenHighlighted = true
        return button
    }()
    
    let audioLengthLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "05:00"
        label.textColor = .black
        label.font = .boldSystemFont(ofSize: 12)
        label.textAlignment = .right
        return label
    }()
    
    let activityIndicatorView: UIActivityIndicatorView = {
        let aiv = UIActivityIndicatorView(activityIndicatorStyle: .whiteLarge)
        aiv.translatesAutoresizingMaskIntoConstraints = false
        aiv.startAnimating()
        return aiv
    }()
    
    var controlContainerView: UIView?
    
    func zoomUserProfileImageView(){
    }
    
    func setupControlContainerView(){
        controlContainerView = UIView()
        controlContainerView?.backgroundColor = UIColor(white: 0, alpha: 0.5)
        //controlContainerView?.frame = frame
        controlContainerView?.translatesAutoresizingMaskIntoConstraints = false
        addSubview(controlContainerView!)
        controlContainerView?.addSubview(activityIndicatorView)
        if #available(iOS 9.0, *) {
            controlContainerView?.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
            controlContainerView?.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
            controlContainerView?.centerXAnchor.constraint(equalTo: centerXAnchor).isActive = true
            controlContainerView?.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
            activityIndicatorView.centerXAnchor.constraint(equalTo: controlContainerView!.centerXAnchor).isActive = true
            activityIndicatorView.centerYAnchor.constraint(equalTo: controlContainerView!.centerYAnchor).isActive = true
        } else {
            // Fallback on earlier versions
        }
        activityIndicatorView.startAnimating()
    }
    
    func clearControlContainerView(){
        controlContainerView?.backgroundColor = .clear
        activityIndicatorView.stopAnimating()
        controlContainerView?.removeFromSuperview()
    }
    
    func handlePlayPause(){
        var pausePlayImage = UIImage(named: "Circled Pause Filled-100")
        if isPlaying {
            print("pause")
            audioPlayer?.pause()
            pausePlayImage = UIImage(named: "Circled Play Filled-100")
            isPlaying = false
            
        } else {
            print("play")
            audioPlayer?.play()
            setupControlContainerView()
            updater = CADisplayLink(target: self, selector: #selector(handleSliderChange))
            updater.add(to: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
            pausePlayImage = UIImage(named: "Circled Pause Filled-100")
            isPlaying = true
        }
        pausePlayButton.setImage(pausePlayImage, for: .normal)
    }
    
    func handleSliderChange(){
        if let progress = audioPlayer?.currentTime {
            audioSlider.setValue(Float(progress), animated: false)
            let secondsString = String(format: "%02d", Int(remainder(progress, 60)))
            let minutesString = String(format: "%02d", Int(progress / 60))
            currentTimeLabel.text = "\(minutesString):\(secondsString)"
            if progress != 0.0 {
                clearControlContainerView()
            }
        }
    }
    
    func handleSliderSlide(){
        audioPlayer?.currentTime = TimeInterval(audioSlider.value)
    }
    
    func setupPlayer(urlAudio: URL){
        do{
            let soundData = try Data.init(contentsOf: urlAudio)
            audioPlayer = try AVAudioPlayer(data: soundData)
            audioPlayer?.prepareToPlay()
            audioPlayer?.volume = 1
            audioPlayer?.delegate = self
        } catch {
            print("error")
        }
    }
    
    func getFileURL(urlString: String) -> URL{
        let filePath = URL(string: urlString)
        return filePath!
    }
    
    func audioPlayerDidFinishPlaying(_ audioPlayer: AVAudioPlayer, successfully flag: Bool){
        let pausePlayImage = UIImage(named: "Circled Play Filled-100")
        pausePlayButton.setImage(pausePlayImage, for: .normal)
        isPlaying = false
    }
    
    var topConstraintTitleLabel: NSLayoutConstraint?
    var topConstraintUsernameLabel: NSLayoutConstraint?
    
    func setupViews(){
        backgroundColor = UIColor(white: 0.99, alpha: 1)
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 0.3
        
        addSubview(userProfileImageView)
        if #available(iOS 9.0, *) {
            userProfileImageView.leftAnchor.constraint(equalTo: leftAnchor, constant: 7).isActive = true
            userProfileImageView.topAnchor.constraint(equalTo: topAnchor, constant: 7).isActive = true
            userProfileImageView.widthAnchor.constraint(equalToConstant: 44).isActive = true
            userProfileImageView.heightAnchor.constraint(equalToConstant: 44).isActive = true
        }
        
        userProfileImageView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(zoomUserProfileImageView)))
        
        addSubview(titleLabel)
        //top constraint
        topConstraintTitleLabel = NSLayoutConstraint(item: titleLabel, attribute: .top, relatedBy: .equal, toItem: userProfileImageView, attribute: .top, multiplier: 1, constant: 4)
        addConstraint(topConstraintTitleLabel!)
        //left constraint
        addConstraint(NSLayoutConstraint(item: titleLabel, attribute: .left, relatedBy: .equal, toItem: userProfileImageView, attribute: .right, multiplier: 1, constant: 4))
        addConstraint(NSLayoutConstraint(item: titleLabel, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1, constant: -40))
        //height constraint
        addConstraint(NSLayoutConstraint(item: titleLabel, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 0, constant: 20))
        
        addSubview(userNameLabel)
        //top constraint
        topConstraintUsernameLabel = NSLayoutConstraint(item: userNameLabel, attribute: .top, relatedBy: .equal, toItem: titleLabel, attribute: .bottom, multiplier: 1, constant: -4)
        addConstraint(topConstraintUsernameLabel!)
        //left constraint
        addConstraint(NSLayoutConstraint(item: userNameLabel, attribute: .left, relatedBy: .equal, toItem: userProfileImageView, attribute: .right, multiplier: 1, constant: 4))
        //height constraint
        addConstraint(NSLayoutConstraint(item: userNameLabel, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 0, constant: 20))
        
        addSubview(recordIdLabel)
        //top constraint
        addConstraint(NSLayoutConstraint(item: recordIdLabel, attribute: .top, relatedBy: .equal, toItem: userNameLabel, attribute: .top, multiplier: 1, constant: 0))
        //height constraint
        addConstraint(NSLayoutConstraint(item: recordIdLabel, attribute: .height, relatedBy: .equal, toItem: userNameLabel, attribute: .height, multiplier: 1, constant: 0))
        //width constraint
        addConstraint(NSLayoutConstraint(item: recordIdLabel, attribute: .width, relatedBy: .equal, toItem: userNameLabel, attribute: .height, multiplier: 1, constant: 10))
        //left constraint
        addConstraint(NSLayoutConstraint(item: recordIdLabel, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1, constant: -4))
        
        addSubview(currentTimeLabel)
        addConstraint(NSLayoutConstraint(item: currentTimeLabel, attribute: .top, relatedBy: .equal, toItem: userProfileImageView, attribute: .bottom, multiplier: 1, constant: 4))
        addConstraint(NSLayoutConstraint(item: currentTimeLabel, attribute: .left, relatedBy: .equal, toItem: userProfileImageView, attribute: .left, multiplier: 1, constant: 0))
        
        addSubview(audioLengthLabel)
        addSubview(pausePlayButton)
        addSubview(audioSlider)
        if #available(iOS 9.0, *) {
            audioLengthLabel.rightAnchor.constraint(equalTo: recordIdLabel.rightAnchor, constant: -4).isActive = true
            audioLengthLabel.topAnchor.constraint(equalTo: currentTimeLabel.topAnchor).isActive = true
            audioSlider.leftAnchor.constraint(equalTo: currentTimeLabel.rightAnchor, constant: 4).isActive = true
            audioSlider.rightAnchor.constraint(equalTo: audioLengthLabel.leftAnchor, constant: -4).isActive = true
            audioSlider.heightAnchor.constraint(equalToConstant: 30).isActive = true
            audioSlider.topAnchor.constraint(equalTo: currentTimeLabel.topAnchor, constant: -7).isActive = true
            pausePlayButton.centerXAnchor.constraint(equalTo: self.centerXAnchor).isActive = true
            pausePlayButton.centerYAnchor.constraint(equalTo: audioSlider.centerYAnchor, constant: 40).isActive = true
            pausePlayButton.widthAnchor.constraint(equalToConstant: 50).isActive = true
            pausePlayButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        } else {
            // Fallback on earlier versions
        }
        
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented!")
    }
    
}

class WordCell: BaseCell {
    
    let cardView: WordCard = {
        let view = WordCard()
        return view
    }()
    
    let separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = .lightGray
        return view
    }()
    
    override func setupViews(){
        addSubview(cardView)
        addSubview(separatorView)
        addConstraint(format: "H:|-16-[v0]-16-|", views: cardView)
        addConstraint(format: "V:|-16-[v0]-16-[v1(1)]|", views: cardView, separatorView)
        addConstraint(format: "H:|[v0]|", views: separatorView)
    }
    
}


class RequestBaseCell: WordCard {
    
    var requestCell: RequestCell?
    //var myRequestCell: MyRequestCell?
    
    var requestList: Words? {
        didSet {
            if let user = requestList?.create_uid {
                userNameLabel.text = user.name
            }
            
            if let words_id = requestList {
                recordIdLabel.text = "#\(words_id.name!)"
            }
            
            titleLabel.text = requestList?.title
            
            setupProfileImage()
            
            if let audioLength = requestList?.length {
                let seconds = Float64(audioLength)
                let secondsText = String(format: "%02d", Int(remainder(seconds, 60)))
                let minuteText = String(format: "%02d", Int(seconds)/60)
                audioLengthLabel.text = "\(minuteText):\(secondsText)"
                audioSlider.maximumValue = Float(audioLength)
            }
            
            if let wordFileUrlString = requestList?.file {
                //audioPlayer = nil
                //audioPlayer?.currentTime = 0.0
                urlAudio = getFileURL(urlString: wordFileUrlString)
            }
        }
    }
    
    func setupProfileImage(){
        if let profileImageUrl = requestList?.create_uid?.profile_image{
            userProfileImageView.loadImageWithUrlString(urlString: profileImageUrl)
        }
    }
    
    override func handlePlayPause() {
        if let cardsPlayTemp = requestCell?.requestListCell?.wordRequestCardTemp.filter({($0.audioPlayer?.isPlaying == true && $0 != self)}){
            for card in cardsPlayTemp {
                card.audioPlayer?.pause()
                card.handlePlayPause()
            }
        }
        if audioPlayer == nil {
            if urlAudio != nil {
                if let listCell = requestCell?.requestListCell{
                    if !listCell.wordRequestCardTemp.contains(self){
                        listCell.wordRequestCardTemp.append(self)
                    }
                }
                setupPlayer(urlAudio: urlAudio!)
                audioSlider.isUserInteractionEnabled = true

            }
        }
        super.handlePlayPause()
    }
    
    override func setupViews() {
        super.setupViews()
        //        topConstraintUsernameLabel?.constant += 15
        //        addSubview(titleLabel)
        //        addConstraint(NSLayoutConstraint(item: titleLabel, attribute: .bottom, relatedBy: .equal, toItem: userNameLabel, attribute: .top, multiplier: 1, constant: 4))
        //        addConstraint(NSLayoutConstraint(item: titleLabel, attribute: .left, relatedBy: .equal, toItem: userNameLabel, attribute: .left, multiplier: 1, constant: 0))
    }
    
}

class RequestWordCard: RequestBaseCell{
    
    lazy var answerButton: MDButton = {
        let button = MDButton(type: .system)
        let attributedTitle = NSAttributedString(string: NSLocalizedString("Answer", comment:"for requestwordcard"), attributes:
            [
                NSFontAttributeName : UIFont.boldSystemFont(ofSize: 24),
                NSForegroundColorAttributeName : UIColor.white,
                ]
        )
        button.setAttributedTitle(attributedTitle, for: .normal)
        button.backgroundColor = UIColor(red: 218/255, green: 165/255, blue: 32/255, alpha: 1)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()
    
    override func zoomUserProfileImageView() {
        //requestCell?.requestListCell?.postController?.animate(userProfileImageView: userProfileImageView)
    }
    
    override func setupViews(){
        super.setupViews()
        addSubview(answerButton)
        if #available(iOS 9.0, *) {
            answerButton.topAnchor.constraint(equalTo: pausePlayButton.bottomAnchor, constant: 2).isActive = true
            answerButton.leftAnchor.constraint(equalTo: leftAnchor).isActive = true
            answerButton.rightAnchor.constraint(equalTo: rightAnchor).isActive = true
            answerButton.heightAnchor.constraint(equalToConstant: 36).isActive = true
        } else {
            // Fallback on earlier versions
        }
    }
    
    
}

class RequestCell: WordCell {
    
    var requestListCell: RequestListCell?
    
    lazy var requestWordCard: RequestWordCard = {
        let view = RequestWordCard()
        view.requestCell = self
        return view
    }()
    
    override func setupViews(){
        addSubview(requestWordCard)
        addSubview(separatorView)
        addConstraint(format: "H:|-16-[v0]-16-|", views: requestWordCard)
        addConstraint(format: "V:|-16-[v0]-16-[v1(1)]|", views: requestWordCard, separatorView)
        addConstraint(format: "H:|[v0]|", views: separatorView)
    }
}


class ApiService: NSObject {
    
    static let sharedInstance = ApiService()
    
    func buildUrlStringWithToken(urlString: String) -> String {
        //let userToken = getLoginToken()
        //if let login = userToken.get("login"), let access_token = userToken.get("access_token"){
            return "\(baseUrl)/\(urlString)/demo@hobbou.com/deee7a3f7bfb5974dda395fe931d0faa109db893".addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed)!
        //}
        //return ""
    }
    
    func fetchRequestWordsList(searchString: String = "", offset: Int, completion: @escaping ([Words]) -> ()){
        if searchString != ""{
            fetchWords(urlString: buildUrlStringWithToken(urlString: "word_req/search/\(searchString)/exclude_uid/offset/\(offset)"), completion: completion)
            if searchString.characters.count > 3 {

            }
        } else {
            fetchWords(urlString: buildUrlStringWithToken(urlString: "word_req/exclude_uid/offset/\(offset)"), completion: completion)
        }
    }
    
    
    func fetchWords(urlString: String, completion: @escaping ([Words]) ->()){
        let url = URL(string: urlString)
        URLSession.shared.dataTask(with: url!) { (data, response, error) in
            if error != nil {
                print(error!)
                return
            }
            do{
                if let unwrappedData = data, let jsonDictionaries = try JSONSerialization.jsonObject(with: unwrappedData, options: .mutableContainers) as? [[String: AnyObject]]{
                    let words = jsonDictionaries.map({
                        return Words(dictionary: $0)
                    })
                    DispatchQueue.main.async(execute: {
                        completion(words)
                    })
                }
                
            } catch let jsonError {
                print(jsonError)
            }
            
            }.resume()
    }
    
}

let imageCache = NSCache<NSString, UIImage>()

class CachedImageView: UIImageView {
    
    //var imageUrlString: URL?
    
    func loadImageWithUrlString(urlString: String){
        let imageUrl = URL(string: urlString)
        
        //set default image
        image = UIImage(named: "Circled User Male Filled-100")
        
        /*if let imageFromCache = imageCache.object(forKey: urlString as NSString){
         self.image = imageFromCache
         return
         }
         URLSession.shared.dataTask(with: imageUrlString!, completionHandler: { (data, response, error) in
         if error != nil {
         print(error!)
         return
         }
         DispatchQueue.main.async(execute: {
         let imageToCache = UIImage(data: data!)
         if self.imageUrlString == urlString{
         self.image = imageToCache
         }
         imageCache.setObject(imageToCache!, forKey: urlString as NSString)
         })
         
         }).resume()
         */
        sd_setImage(with: imageUrl, placeholderImage: image, options: [.retryFailed, .progressiveDownload]) { (image, error, cacheType, url) in
            if let error = error {
                print("load image error:", error)
            }
        }
        
    }
}

