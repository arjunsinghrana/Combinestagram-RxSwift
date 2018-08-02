/*
 * Copyright (c) 2016-present Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import RxSwift

class MainViewController: UIViewController {
    
    @IBOutlet weak var imagePreview: UIImageView!
    @IBOutlet weak var buttonClear: UIButton!
    @IBOutlet weak var buttonSave: UIButton!
    @IBOutlet weak var itemAdd: UIBarButtonItem!
    @IBOutlet weak var leftBarButtonItem: UIBarButtonItem!
    
    private let bag = DisposeBag()
    private let images = Variable<[UIImage]>([])
    private var imageCache = [Int]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let latestImages = images.asObservable().share()
        
        latestImages
            .throttle(0.5, scheduler: MainScheduler.instance)
            .subscribe(onNext: { (photos) in
                guard let preview = self.imagePreview else {
                    return
                }
                preview.image = UIImage.collage(images: photos, size: preview.frame.size)
            })
            .disposed(by: bag)
        
        latestImages
            .subscribe(onNext: { [weak self] (photos) in
                self?.updateUI(photos: photos)
            })
            .disposed(by: bag)
    }
    
    private func updateUI(photos: [UIImage]) {
        buttonSave.isEnabled = photos.count > 0 && photos.count % 2 == 0
        buttonClear.isEnabled = photos.count > 0
        itemAdd.isEnabled = photos.count < 6
        title = photos.count > 0 ? "\(photos.count)" : "Collage"
    }
    
    @IBAction func actionClear() {
        images.value = []
        imageCache = []
    }
    
    @IBAction func actionSave() {
        guard let image = imagePreview.image else { return }
        
        PhotoWriter.save(image)
            .asSingle()
            .subscribe(onSuccess: { [weak self] id in
                self?.showMessage("Saved with id: \(id)")
                self?.actionClear()
                }, onError: { [weak self] error in
                    self?.showMessage("Error", description: error.localizedDescription)
            })
            .disposed(by: bag)
    }
    
    @IBAction func actionAdd() {
        // images.value.append(UIImage(named: "IMG_1907.jpg")!)
        
        let photosVC = storyboard?.instantiateViewController(withIdentifier: "PhotosViewController") as! PhotosViewController
        
        let newPhoto = photosVC.selectedPhoto.share()
        
        newPhoto
            .takeWhile({ [weak self] (image) -> Bool in
                return (self?.images.value.count ?? 0) < 6
            })
            .filter({ (newImage) -> Bool in
                return newImage.size.width > newImage.size.height
            })
            .filter({ [weak self] (newImage) -> Bool in
                let len = UIImagePNGRepresentation(newImage)?.count ?? 0
                guard self?.imageCache.contains(len) == false else {
                    return false
                }
                self?.imageCache.append(len)
                return true
            })
            .subscribe(
                onNext: { [weak self] (newImage) in
                    guard let images = self?.images else {
                        return
                    }
                    images.value.append(newImage)
                },
                onDisposed: {
                    print("Completed photo selection")
                }
            )
            .disposed(by: photosVC.bag)
        
        newPhoto
            .ignoreElements()
            .subscribe(onCompleted: { [weak self] in
                self?.updateNavigationIcon()
            })
            .disposed(by: bag)
        
        navigationController?.pushViewController(photosVC, animated: true)
    }
    
    func showMessage(_ title: String, description: String? = nil) {
        let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close", style: .default, handler: { [weak self] _ in self?.dismiss(animated: true, completion: nil)}))
        present(alert, animated: true, completion: nil)
    }
    
    private func updateNavigationIcon() {
        let icon = imagePreview.image?
                        .scaled(CGSize(width: 22, height: 22))
                        .withRenderingMode(.alwaysOriginal)
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: icon, style: .done, target: nil, action: nil)
    }
}
